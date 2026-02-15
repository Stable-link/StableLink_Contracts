// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Faucet
 * @notice Daily token faucet for testnet users
 * @dev Allows users to claim tokens once per day
 */
contract Faucet is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public claimAmount;
    uint256 public constant CLAIM_COOLDOWN = 1 days;

    mapping(address => uint256) public lastClaimTime;

    event TokensClaimed(address indexed user, uint256 amount);
    event ClaimAmountUpdated(uint256 newAmount);

    /**
     * @param _token Address of the ERC20 token to distribute
     * @param _claimAmount Amount of tokens users can claim per day (in token units)
     */
    constructor(address _token, uint256 _claimAmount) Ownable(msg.sender) {
        require(_token != address(0), "Faucet: invalid token address");
        token = IERC20(_token);
        claimAmount = _claimAmount;
    }

    /**
     * @notice Claim tokens from the faucet (once per day)
     */
    function claim() external nonReentrant {
        address user = msg.sender;
        uint256 lastClaim = lastClaimTime[user];
        uint256 currentTime = block.timestamp;

        require(
            currentTime >= lastClaim + CLAIM_COOLDOWN,
            "Faucet: claim cooldown not expired"
        );

        lastClaimTime[user] = currentTime;
        token.safeTransfer(user, claimAmount);

        emit TokensClaimed(user, claimAmount);
    }

    /**
     * @notice Check if a user can claim tokens now
     * @param user Address to check
     * @return canClaimNow True if user can claim now
     * @return timeUntilClaim Seconds until user can claim again (0 if can claim now)
     */
    function canClaim(address user) external view returns (bool canClaimNow, uint256 timeUntilClaim) {
        uint256 lastClaim = lastClaimTime[user];
        uint256 currentTime = block.timestamp;
        
        if (lastClaim == 0) {
            // Never claimed before
            return (true, 0);
        }

        uint256 timeSinceLastClaim = currentTime - lastClaim;
        if (timeSinceLastClaim >= CLAIM_COOLDOWN) {
            return (true, 0);
        } else {
            return (false, CLAIM_COOLDOWN - timeSinceLastClaim);
        }
    }

    /**
     * @notice Update the claim amount (owner only)
     * @param newAmount New claim amount per day
     */
    function setClaimAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Faucet: claim amount must be > 0");
        claimAmount = newAmount;
        emit ClaimAmountUpdated(newAmount);
    }

    /**
     * @notice Withdraw tokens from faucet (owner only)
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external onlyOwner {
        token.safeTransfer(owner(), amount);
    }

    /**
     * @notice Deposit tokens into faucet
     * @param amount Amount to deposit
     */
    function deposit(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
    }
}
