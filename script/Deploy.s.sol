// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/InvoicePayments.sol";

contract DeployScript is Script {
    function run() external returns (InvoicePayments) {
        // Pass deployer via --private-key when broadcasting. Platform fee recipient from env or deployer.
        address platformFeeRecipient = vm.envOr("PLATFORM_FEE_RECIPIENT", address(0));
        if (platformFeeRecipient == address(0)) {
            // Default to msg.sender (the account set by --private-key)
            platformFeeRecipient = msg.sender;
        }

        vm.startBroadcast();
        InvoicePayments ip = new InvoicePayments(platformFeeRecipient);
        vm.stopBroadcast();

        console.log("InvoicePayments deployed at:", address(ip));
        console.log("Platform fee recipient:", platformFeeRecipient);
        return ip;
    }
}
