// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

/**
 * @title NativeBridge
 * @dev Bridge contract for locking and releasing native coins (ETH) between chains
 */
contract NativeBridge is PermissionsEnumerable, ContractMetadata, Multicall, ReentrancyGuard {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    address public owner;
    address public deployer;

    mapping(address => uint256) public lockedBalances;
    mapping(bytes32 => bool) public processedTransactions;

    event Lock(address indexed user, uint256 amount, uint256 timestamp);
    event Release(address indexed user, uint256 amount, uint256 timestamp, bytes32 indexed fromTxHash);
    event Deposit(address indexed from, uint256 amount);

    /**
     * @dev Constructor
     */
    constructor(string memory _contractURI) {
        _setupContractURI(_contractURI);
        deployer = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    /**
     * @dev Lock native coins in the bridge
     */
    function lock() external payable nonReentrant {
        require(msg.value > 0, "Amount must be greater than 0");

        lockedBalances[msg.sender] += msg.value;

        emit Lock(msg.sender, msg.value, block.timestamp);
    }

    /**
     * @dev Release native coins to a user (only owner can call this)
     * @param user Address of the user to release coins to
     * @param amount Amount of coins to release
     * @param fromTxHash Transaction hash from the source chain Lock transaction
     */
    function release(address payable user, uint256 amount, bytes32 fromTxHash) external onlyRole(FACTORY_ROLE) nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(fromTxHash != bytes32(0), "Invalid transaction hash");
        require(!processedTransactions[fromTxHash], "Transaction already processed");
        require(address(this).balance >= amount, "Insufficient balance");

        // Mark transaction as processed
        processedTransactions[fromTxHash] = true;

        (bool success, ) = user.call{value: amount}("");
        require(success, "Transfer failed");

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
    function emergencyWithdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
    }

    /**
     * @dev Get the balance of the bridge
     * @return Balance of native coins in the bridge
     */
    function getBridgeBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Receive function to accept native coins
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @dev Fallback function
     */
    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
