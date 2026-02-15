// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Fund the Faucet contract with TestUSDC tokens.
 * Requires: TEST_USDC_ADDRESS, FAUCET_ADDRESS in .env
 * Optional: FAUCET_FUND_AMOUNT (default: 100_000 * 10^6 = 100k tUSDC)
 */
contract FundFaucetScript is Script {
    function run() external {
        address tokenAddress = vm.envAddress("TEST_USDC_ADDRESS");
        address faucetAddress = vm.envAddress("FAUCET_ADDRESS");
        // Default: 100,000 tUSDC (6 decimals)
        uint256 amount = vm.envOr("FAUCET_FUND_AMOUNT", uint256(100_000 * 10 ** 6));

        vm.startBroadcast();
        bool ok = IERC20(tokenAddress).transfer(faucetAddress, amount);
        require(ok, "Transfer failed");
        vm.stopBroadcast();

        console.log("Transferred", amount, "tUSDC (raw) to faucet", faucetAddress);
        console.log("Faucet balance:", IERC20(tokenAddress).balanceOf(faucetAddress));
    }
}
