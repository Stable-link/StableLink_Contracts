// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/TestUSDC.sol";

contract DeployTestUSDCScript is Script {
    function run() external returns (TestUSDC) {
        vm.startBroadcast();
        TestUSDC token = new TestUSDC();
        vm.stopBroadcast();

        console.log("TestUSDC deployed at:", address(token));
        console.log("Token name:", token.name());
        console.log("Token symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        console.log("Initial supply:", token.totalSupply());
        
        return token;
    }
}
