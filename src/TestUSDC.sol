// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TestUSDC
 * @notice Test token for ShadowNet with 6 decimals (matching real USDC)
 * @dev This is a mintable ERC20 token for testing purposes only
 */
contract TestUSDC is ERC20 {
    uint8 private constant _DECIMALS = 6;

    constructor() ERC20("Test USDC", "tUSDC") {
        // Mint initial supply to deployer (1 million tokens)
        _mint(msg.sender, 1_000_000 * 10 ** _DECIMALS);
    }

    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    /**
     * @notice Mint tokens to an address (for faucet or admin use)
     * @param to Address to mint tokens to
     * @param amount Amount to mint (in token units, will be multiplied by decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
