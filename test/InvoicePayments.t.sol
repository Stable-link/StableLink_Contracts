// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/InvoicePayments.sol";
import "./MockERC20.sol";

contract InvoicePaymentsTest is Test {
    InvoicePayments public ip;
    MockERC20 public token;

    address public owner;
    address public creator;
    address public recipient1;
    address public recipient2;
    address public payer;

    uint16 constant BASIS_POINTS = 10000;

    function setUp() public {
        owner = address(1);
        creator = address(2);
        recipient1 = address(3);
        recipient2 = address(4);
        payer = address(5);

        vm.deal(payer, 1 ether);

        vm.startPrank(owner);
        ip = new InvoicePayments(owner);
        vm.stopPrank();

        token = new MockERC20("Test USDC", "USDC");
        token.mint(payer, 1_000_000 * 1e18);
    }

    function test_Deploy() public view {
        assertEq(ip.platformFeeRecipient(), owner);
        assertEq(ip.nextInvoiceId(), 0);
        assertEq(ip.BASIS_POINTS(), BASIS_POINTS);
        assertEq(ip.platformFeeBps(), 300);
    }

    function test_CreateInvoice_Success() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](2);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: 9700 });
        splits[1] = InvoicePayments.Split({ recipient: recipient2, percentage: 300 });

        vm.prank(creator);
        uint256 id = ip.createInvoice(1000e18, address(token), splits);

        assertEq(id, 0);
        assertEq(ip.nextInvoiceId(), 1);

        (address c, address t, uint256 amt, bool paid, bool cancelled) = ip.invoices(0);
        assertEq(c, creator);
        assertEq(t, address(token));
        assertEq(amt, 1000e18);
        assertFalse(paid);
        assertFalse(cancelled);

        InvoicePayments.Split[] memory stored = ip.getInvoiceSplits(0);
        assertEq(stored.length, 2);
        assertEq(stored[0].recipient, recipient1);
        assertEq(stored[0].percentage, 9700);
        assertEq(stored[1].recipient, recipient2);
        assertEq(stored[1].percentage, 300);
    }

    function test_CreateInvoice_RevertZeroAmount() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        vm.expectRevert(InvoicePayments.InvalidAmount.selector);
        ip.createInvoice(0, address(token), splits);
    }

    function test_CreateInvoice_RevertZeroToken() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        vm.expectRevert(InvoicePayments.InvalidToken.selector);
        ip.createInvoice(1000e18, address(0), splits);
    }

    function test_CreateInvoice_RevertEmptySplits() public {
        InvoicePayments.Split[] memory splits;

        vm.prank(creator);
        vm.expectRevert(InvoicePayments.InvalidSplits.selector);
        ip.createInvoice(1000e18, address(token), splits);
    }

    function test_CreateInvoice_RevertInvalidSplitSum_Over() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](2);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: 6000 });
        splits[1] = InvoicePayments.Split({ recipient: recipient2, percentage: 5000 }); // 11000 != BASIS_POINTS

        vm.prank(creator);
        vm.expectRevert(InvoicePayments.InvalidSplitSum.selector);
        ip.createInvoice(1000e18, address(token), splits);
    }

    function test_CreateInvoice_RevertInvalidSplitSum_Under() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: 9999 });

        vm.prank(creator);
        vm.expectRevert(InvoicePayments.InvalidSplitSum.selector);
        ip.createInvoice(1000e18, address(token), splits);
    }

    function test_PayInvoice_Success() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](2);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: 9700 });
        splits[1] = InvoicePayments.Split({ recipient: recipient2, percentage: 300 });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.startPrank(payer);
        token.approve(address(ip), 1000e18);
        ip.payInvoice(0);
        vm.stopPrank();

        (, , , bool paid, ) = ip.invoices(0);
        assertTrue(paid);
        assertEq(ip.balances(recipient1, address(token)), 970e18);  // 97%
        assertEq(ip.balances(recipient2, address(token)), 30e18);   // 3%
    }

    function test_PayInvoice_RevertDoublePayment() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.startPrank(payer);
        token.approve(address(ip), 2000e18);
        ip.payInvoice(0);
        vm.expectRevert(InvoicePayments.AlreadyPaid.selector);
        ip.payInvoice(0);
        vm.stopPrank();
    }

    function test_PayInvoice_RevertCancelled() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.prank(creator);
        ip.cancelInvoice(0);

        vm.startPrank(payer);
        token.approve(address(ip), 1000e18);
        vm.expectRevert(InvoicePayments.Cancelled.selector);
        ip.payInvoice(0);
        vm.stopPrank();
    }

    function test_PayInvoice_RevertNotFound() public {
        vm.prank(payer);
        vm.expectRevert(InvoicePayments.InvoiceNotFound.selector);
        ip.payInvoice(999);
    }

    function test_SplitAllocation_Precision() public {
        // 1000e18 with 2500, 2500, 5000 bps -> 250, 250, 500 (exact, no dust)
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](3);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: 2500 });
        splits[1] = InvoicePayments.Split({ recipient: recipient2, percentage: 2500 });
        splits[2] = InvoicePayments.Split({ recipient: owner, percentage: 5000 });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.startPrank(payer);
        token.approve(address(ip), 1000e18);
        ip.payInvoice(0);
        vm.stopPrank();

        assertEq(ip.balances(recipient1, address(token)), 250e18);
        assertEq(ip.balances(recipient2, address(token)), 250e18);
        assertEq(ip.balances(owner, address(token)), 500e18);
        assertEq(
            ip.balances(recipient1, address(token)) + ip.balances(recipient2, address(token)) + ip.balances(owner, address(token)),
            1000e18
        );
    }

    function test_Withdraw_Success() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.startPrank(payer);
        token.approve(address(ip), 1000e18);
        ip.payInvoice(0);
        vm.stopPrank();

        uint256 balBefore = token.balanceOf(recipient1);
        vm.prank(recipient1);
        ip.withdraw(address(token), 500e18);
        assertEq(token.balanceOf(recipient1), balBefore + 500e18);
        assertEq(ip.balances(recipient1, address(token)), 500e18);
    }

    function test_Withdraw_RevertInsufficientBalance() public {
        vm.prank(recipient1);
        vm.expectRevert(InvoicePayments.InsufficientBalance.selector);
        ip.withdraw(address(token), 1);
    }

    function test_Withdraw_RevertZeroAmount() public {
        vm.prank(recipient1);
        vm.expectRevert(InvoicePayments.ZeroAmount.selector);
        ip.withdraw(address(token), 0);
    }

    function test_CancelInvoice_Success() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.prank(creator);
        ip.cancelInvoice(0);

        (, , , , bool cancelled) = ip.invoices(0);
        assertTrue(cancelled);
    }

    function test_CancelInvoice_RevertNotCreator() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.prank(payer);
        vm.expectRevert(InvoicePayments.Unauthorized.selector);
        ip.cancelInvoice(0);
    }

    function test_CancelInvoice_RevertAlreadyPaid() public {
        InvoicePayments.Split[] memory splits = new InvoicePayments.Split[](1);
        splits[0] = InvoicePayments.Split({ recipient: recipient1, percentage: BASIS_POINTS });

        vm.prank(creator);
        ip.createInvoice(1000e18, address(token), splits);

        vm.startPrank(payer);
        token.approve(address(ip), 1000e18);
        ip.payInvoice(0);
        vm.stopPrank();

        vm.prank(creator);
        vm.expectRevert(InvoicePayments.AlreadyPaid.selector);
        ip.cancelInvoice(0);
    }

    function test_Owner_SetPlatformFeeRecipient() public {
        vm.prank(owner);
        ip.setPlatformFeeRecipient(recipient1);
        assertEq(ip.platformFeeRecipient(), recipient1);
    }

    function test_Owner_SetPlatformFeeBps() public {
        vm.prank(owner);
        ip.setPlatformFeeBps(500);
        assertEq(ip.platformFeeBps(), 500);
    }

    function test_Owner_SetPlatformFeeBps_RevertOverCap() public {
        vm.prank(owner);
        vm.expectRevert();
        ip.setPlatformFeeBps(1001);
    }
}
