// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title InvoicePayments
 * @notice Non-custodial stablecoin invoice and programmable payment system for StableLink (Etherlink).
 * @dev See StableLink_SmartContracts_Specification.md for full spec.
 */
contract InvoicePayments is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint16 public constant BASIS_POINTS = 10000;
    uint16 public platformFeeBps = 300; // 3%
    address public platformFeeRecipient;

    uint256 public nextInvoiceId;

    struct Invoice {
        address creator;
        address token;
        uint256 amount;
        bool paid;
        bool cancelled;
    }

    struct Split {
        address recipient;
        uint16 percentage; // basis points
    }

    mapping(uint256 => Invoice) public invoices;
    mapping(uint256 => Split[]) private invoiceSplits;
    mapping(address => mapping(address => uint256)) public balances;

    event InvoiceCreated(
        uint256 indexed invoiceId,
        address indexed creator,
        address indexed token,
        uint256 amount
    );
    event InvoicePaid(uint256 indexed invoiceId, address indexed payer, uint256 amount);
    event FundsAllocated(
        uint256 indexed invoiceId,
        address indexed recipient,
        uint256 amount
    );
    event Withdrawal(address indexed user, address indexed token, uint256 amount);
    event InvoiceCancelled(uint256 indexed invoiceId);

    error InvalidAmount();
    error InvalidToken();
    error InvalidSplits();
    error InvalidSplitSum();
    error InvoiceNotFound();
    error AlreadyPaid();
    error Cancelled();
    error Unauthorized();
    error InsufficientBalance();
    error ZeroAmount();

    constructor(address _platformFeeRecipient) Ownable(msg.sender) {
        platformFeeRecipient = _platformFeeRecipient;
    }

    function createInvoice(
        uint256 amount,
        address token,
        Split[] calldata splits
    ) external returns (uint256 invoiceId) {
        if (amount == 0) revert InvalidAmount();
        if (token == address(0)) revert InvalidToken();
        if (splits.length == 0) revert InvalidSplits();

        uint256 totalBps;
        for (uint256 i; i < splits.length; ) {
            totalBps += splits[i].percentage;
            unchecked {
                ++i;
            }
        }
        if (totalBps != BASIS_POINTS) revert InvalidSplitSum();

        invoiceId = nextInvoiceId++;
        invoices[invoiceId] = Invoice({
            creator: msg.sender,
            token: token,
            amount: amount,
            paid: false,
            cancelled: false
        });

        for (uint256 i; i < splits.length; ) {
            invoiceSplits[invoiceId].push(splits[i]);
            unchecked {
                ++i;
            }
        }

        emit InvoiceCreated(invoiceId, msg.sender, token, amount);
        return invoiceId;
    }

    function payInvoice(uint256 invoiceId) external nonReentrant {
        Invoice storage inv = invoices[invoiceId];
        if (inv.creator == address(0)) revert InvoiceNotFound();
        if (inv.paid) revert AlreadyPaid();
        if (inv.cancelled) revert Cancelled();

        inv.paid = true;
        IERC20(inv.token).safeTransferFrom(msg.sender, address(this), inv.amount);

        Split[] storage splits = invoiceSplits[invoiceId];
        for (uint256 i; i < splits.length; ) {
            uint256 allocation = (inv.amount * splits[i].percentage) / BASIS_POINTS;
            if (allocation > 0) {
                balances[splits[i].recipient][inv.token] += allocation;
                emit FundsAllocated(invoiceId, splits[i].recipient, allocation);
            }
            unchecked {
                ++i;
            }
        }

        emit InvoicePaid(invoiceId, msg.sender, inv.amount);
    }

    function withdraw(address token, uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender][token] < amount) revert InsufficientBalance();

        balances[msg.sender][token] -= amount;
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, token, amount);
    }

    function cancelInvoice(uint256 invoiceId) external {
        Invoice storage inv = invoices[invoiceId];
        if (inv.creator == address(0)) revert InvoiceNotFound();
        if (inv.creator != msg.sender) revert Unauthorized();
        if (inv.paid) revert AlreadyPaid();
        if (inv.cancelled) revert Cancelled();

        inv.cancelled = true;
        emit InvoiceCancelled(invoiceId);
    }

    function getInvoiceSplits(uint256 invoiceId) external view returns (Split[] memory) {
        return invoiceSplits[invoiceId];
    }

    function setPlatformFeeRecipient(address _recipient) external onlyOwner {
        platformFeeRecipient = _recipient;
    }

    function setPlatformFeeBps(uint16 _bps) external onlyOwner {
        require(_bps <= 1000, "cap 10%");
        platformFeeBps = _bps;
    }
}
