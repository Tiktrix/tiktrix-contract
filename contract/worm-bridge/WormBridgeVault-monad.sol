// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

/**
 * @title WormBridgeVault
 * @dev Vault contract for releasing WORM tokens on Monad
 * Receives locked tokens from MeerChain bridge and releases to users
 * Uses RELAYER_ROLE for access control and meerTxHash for duplicate prevention
 */
contract WormBridgeVault is PermissionsEnumerable, ContractMetadata, Multicall, ReentrancyGuard {
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    address public deployer;

    IERC20 public wormToken;

    /// @dev Tracks processed MeerChain transaction hashes to prevent double-spending
    mapping(bytes32 => bool) public processedTransactions;

    event Release(
        address indexed to,
        uint256 amount,
        bytes32 indexed meerTxHash,
        uint256 timestamp
    );

    event Deposit(
        address indexed from,
        uint256 amount,
        uint256 timestamp
    );

    event EmergencyWithdraw(
        address indexed admin,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev Constructor
     * @param _contractURI Metadata URI for the contract
     * @param _wormToken Address of the WORM token contract on Monad
     */
    constructor(string memory _contractURI, address _wormToken) {
        require(_wormToken != address(0), "Invalid token address");
        wormToken = IERC20(_wormToken);
        deployer = msg.sender;
        _setupContractURI(_contractURI);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(RELAYER_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    /**
     * @dev Release WORM tokens to a user
     * Only accounts with RELAYER_ROLE can call this function
     * @param to Address of the recipient (user's AA wallet on Monad)
     * @param amount Amount of tokens to release
     * @param meerTxHash Lock transaction hash from MeerChain (prevents duplicate releases)
     */
    function release(address to, uint256 amount, bytes32 meerTxHash) external onlyRole(RELAYER_ROLE) nonReentrant {
        require(!processedTransactions[meerTxHash], "Already processed");
        require(meerTxHash != bytes32(0), "Invalid meerTxHash");
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be > 0");
        require(
            wormToken.balanceOf(address(this)) >= amount,
            "Insufficient vault balance"
        );

        // Mark transaction as processed before transfer (CEI pattern)
        processedTransactions[meerTxHash] = true;

        require(wormToken.transfer(to, amount), "Transfer failed");

        emit Release(to, amount, meerTxHash, block.timestamp);
    }

    /**
     * @dev Check if a MeerChain transaction has been processed
     * @param meerTxHash Transaction hash to check
     * @return bool True if processed, false otherwise
     */
    function isProcessed(bytes32 meerTxHash) external view returns (bool) {
        return processedTransactions[meerTxHash];
    }

    /**
     * @dev Get the balance of WORM tokens in the vault
     * @return Balance of WORM tokens available for release
     */
    function getVaultBalance() external view returns (uint256) {
        return wormToken.balanceOf(address(this));
    }

    /**
     * @dev Deposit WORM tokens into the vault
     * Anyone can deposit tokens to fund the vault
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(
            wormToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        emit Deposit(msg.sender, amount, block.timestamp);
    }

    /**
     * @dev Emergency withdraw function (only admin)
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            wormToken.balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );
        require(wormToken.transfer(msg.sender, amount), "Transfer failed");

        emit EmergencyWithdraw(msg.sender, amount, block.timestamp);
    }
}

