// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TrixBridge
 * @dev Bridge contract for locking and releasing TRIX tokens between Ethereum and Meer Chain
 */
contract TrixBridge is Ownable, ReentrancyGuard {
    IERC20 public trixToken;

    mapping(address => uint256) public lockedBalances;
    mapping(bytes32 => bool) public processedTransactions;

    event Lock(address indexed user, uint256 amount, uint256 timestamp);
    event Release(address indexed user, uint256 amount, uint256 timestamp, bytes32 indexed fromTxHash);

    /**
     * @dev Constructor
     * @param _trixToken Address of the TRIX token contract
     */
    constructor(address _trixToken) Ownable(msg.sender) {
        require(_trixToken != address(0), "Invalid token address");
        trixToken = IERC20(_trixToken);
    }

    /**
     * @dev Lock TRIX tokens in the bridge
     * @param amount Amount of tokens to lock
     */
    function lock(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens from user to bridge
        require(
            trixToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        lockedBalances[msg.sender] += amount;

        emit Lock(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Release TRIX tokens to a user (only owner can call this)
     * @param user Address of the user to release tokens to
     * @param amount Amount of tokens to release
     * @param fromTxHash Transaction hash from the source chain Lock transaction
     */
    function release(address user, uint256 amount, bytes32 fromTxHash) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(fromTxHash != bytes32(0), "Invalid transaction hash");
        require(!processedTransactions[fromTxHash], "Transaction already processed");
        require(
            trixToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        // Mark transaction as processed
        processedTransactions[fromTxHash] = true;

        require(trixToken.transfer(user, amount), "Transfer failed");

        emit Release(user, amount, block.timestamp, fromTxHash);
    }

    /**
     * @dev Check if a transaction has been processed
     * @param fromTxHash Transaction hash to check
     * @return bool True if processed, false otherwise
     */
    function isProcessed(bytes32 fromTxHash) external view returns (bool) {
        return processedTransactions[fromTxHash];
    }

    /**
     * @dev Emergency withdraw function (only owner)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(
            trixToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        require(trixToken.transfer(owner(), amount), "Transfer failed");
    }

    /**
     * @dev Get the balance of the bridge
     * @return Balance of TRIX tokens in the bridge
     */
    function getBridgeBalance() external view returns (uint256) {
        return trixToken.balanceOf(address(this));
    }
}
