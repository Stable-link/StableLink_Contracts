// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Faucet.sol";

contract DeployFaucetScript is Script {
    function run() external returns (Faucet) {
        // Get token address from environment or require it
        address tokenAddress = vm.envAddress("TEST_USDC_ADDRESS");
        
        // Default claim amount: 1000 USDC (with 6 decimals = 1000 * 10^6)
        uint256 claimAmount = vm.envOr("FAUCET_CLAIM_AMOUNT", uint256(1000 * 10 ** 6));

        vm.startBroadcast();
        Faucet faucet = new Faucet(tokenAddress, claimAmount);
        vm.stopBroadcast();

        console.log("Faucet deployed at:", address(faucet));
        console.log("Token address:", address(faucet.token()));
        console.log("Claim amount per day:", faucet.claimAmount());
        
        return faucet;
    }
}
