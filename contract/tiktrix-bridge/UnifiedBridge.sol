// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

/**
 * @title UnifiedBridge
 * @dev Unified bridge contract for cross-chain token transfers
 *
 * Supports:
 * - Ethereum <-> Monad (bidirectional)
 * - Meer -> Monad (unidirectional)
 *
 * Uses Lock & Release mechanism with relayer-based execution
 */
contract UnifiedBridge is PermissionsEnumerable, ContractMetadata, Multicall, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256("TOKEN_MANAGER_ROLE");

    // State variables
    address public deployer;
    uint256 public immutable currentChainId;
    bool public paused;

    // Fee settings (basis points: 100 = 1%, 10000 = 100%)
    uint256 public constant MAX_FEE_RATE = 1000; // 최대 10%
    uint256 public feeRate; // 기본 0 (수수료 없음)
    address public feeRecipient;
    mapping(address => uint256) public collectedFees; // 토큰별 수집된 수수료

    // Supported tokens mapping (token address => supported)
    mapping(address => bool) public supportedTokens;

    // Supported destination chains mapping (chainId => supported)
    mapping(uint256 => bool) public supportedDestinationChains;

    // Processed transactions mapping (fromTxHash => processed)
    mapping(bytes32 => bool) public processedTransactions;

    // Locked balances per token per user (token => user => amount)
    mapping(address => mapping(address => uint256)) public lockedBalances;

    // Native token address constant (address(0) represents native token)
    address public constant NATIVE_TOKEN = address(0);

    // Events
    event Lock(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 fee,
        uint256 indexed targetChainId,
        uint256 timestamp
    );

    event Release(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 indexed fromTxHash,
        uint256 timestamp
    );

    event EmergencyWithdraw(
        address indexed admin,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event TokenAdded(address indexed token, uint256 timestamp);
    event TokenRemoved(address indexed token, uint256 timestamp);
    event DestinationChainAdded(uint256 indexed chainId, uint256 timestamp);
    event DestinationChainRemoved(uint256 indexed chainId, uint256 timestamp);
    event Paused(address indexed admin, uint256 timestamp);
    event Unpaused(address indexed admin, uint256 timestamp);
    event Deposit(address indexed depositor, address indexed token, uint256 amount, uint256 timestamp);
    event FeeRateUpdated(uint256 oldFeeRate, uint256 newFeeRate, uint256 timestamp);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient, uint256 timestamp);
    event FeeCollected(address indexed token, address indexed user, uint256 feeAmount, uint256 timestamp);
    event FeeWithdrawn(address indexed token, address indexed recipient, uint256 amount, uint256 timestamp);

    // Modifiers
    modifier whenNotPaused() {
        require(!paused, "Bridge is paused");
        _;
    }

    modifier onlyValidToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }

    modifier onlyValidDestination(uint256 targetChainId) {
        require(supportedDestinationChains[targetChainId], "Destination chain not supported");
        require(targetChainId != currentChainId, "Cannot bridge to same chain");
        _;
    }

    /**
     * @dev Constructor
     * @param _contractURI Contract metadata URI
     * @param _chainId Current chain ID
     */
    constructor(string memory _contractURI, uint256 _chainId) {
        deployer = msg.sender;
        currentChainId = _chainId;
        paused = false;

        _setupContractURI(_contractURI);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(RELAYER_ROLE, msg.sender);
        _setupRole(TOKEN_MANAGER_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    // ============ Core Functions ============

    /**
     * @dev Lock tokens to bridge to another chain
     * @param token Address of the token to lock
     * @param amount Amount of tokens to lock (including fee)
     * @param targetChainId Target chain ID to bridge to
     */
    function lock(
        address token,
        uint256 amount,
        uint256 targetChainId
    ) external nonReentrant whenNotPaused onlyValidToken(token) onlyValidDestination(targetChainId) {
        require(amount > 0, "Amount must be greater than 0");

        // Calculate fee
        uint256 fee = calculateFee(amount);
        uint256 netAmount = amount - fee;
        require(netAmount > 0, "Amount after fee must be greater than 0");

        // Transfer tokens from user to bridge
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Track collected fees
        if (fee > 0) {
            collectedFees[token] += fee;
            emit FeeCollected(token, msg.sender, fee, block.timestamp);
        }

        // Update locked balance (net amount only)
        lockedBalances[token][msg.sender] += netAmount;

        emit Lock(msg.sender, token, netAmount, fee, targetChainId, block.timestamp);
    }

    /**
     * @dev Lock native tokens to bridge to another chain
     * @param targetChainId Target chain ID to bridge to
     */
    function lockNative(
        uint256 targetChainId
    ) external payable nonReentrant whenNotPaused onlyValidDestination(targetChainId) {
        require(supportedTokens[NATIVE_TOKEN], "Native token not supported");
        require(msg.value > 0, "Amount must be greater than 0");

        // Calculate fee
        uint256 fee = calculateFee(msg.value);
        uint256 netAmount = msg.value - fee;
        require(netAmount > 0, "Amount after fee must be greater than 0");

        // Track collected fees
        if (fee > 0) {
            collectedFees[NATIVE_TOKEN] += fee;
            emit FeeCollected(NATIVE_TOKEN, msg.sender, fee, block.timestamp);
        }

        // Update locked balance (net amount only)
        lockedBalances[NATIVE_TOKEN][msg.sender] += netAmount;

        emit Lock(msg.sender, NATIVE_TOKEN, netAmount, fee, targetChainId, block.timestamp);
    }

    /**
     * @dev Release tokens to a user (only relayer can call)
     * @param user Address of the user to release tokens to
     * @param token Address of the token to release
     * @param amount Amount of tokens to release
     * @param sourceChainId Source chain ID where lock occurred
     * @param fromTxHash Transaction hash from the source chain Lock transaction
     */
    function release(
        address user,
        address token,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 fromTxHash
    ) external onlyRole(RELAYER_ROLE) nonReentrant whenNotPaused onlyValidToken(token) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");
        require(fromTxHash != bytes32(0), "Invalid transaction hash");
        require(!processedTransactions[fromTxHash], "Transaction already processed");
        require(sourceChainId != currentChainId, "Invalid source chain");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient bridge balance"
        );

        // Mark transaction as processed
        processedTransactions[fromTxHash] = true;

        // Transfer tokens to user
        IERC20(token).safeTransfer(user, amount);

        emit Release(user, token, amount, sourceChainId, fromTxHash, block.timestamp);
    }

    /**
     * @dev Release native tokens to a user (only relayer can call)
     * @param user Address of the user to release tokens to
     * @param amount Amount of native tokens to release
     * @param sourceChainId Source chain ID where lock occurred
     * @param fromTxHash Transaction hash from the source chain Lock transaction
     */
    function releaseNative(
        address user,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 fromTxHash
    ) external onlyRole(RELAYER_ROLE) nonReentrant whenNotPaused {
        require(supportedTokens[NATIVE_TOKEN], "Native token not supported");
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");
        require(fromTxHash != bytes32(0), "Invalid transaction hash");
        require(!processedTransactions[fromTxHash], "Transaction already processed");
        require(sourceChainId != currentChainId, "Invalid source chain");
        require(address(this).balance >= amount, "Insufficient bridge balance");

        // Mark transaction as processed
        processedTransactions[fromTxHash] = true;

        // Transfer native tokens to user
        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "Native transfer failed");

        emit Release(user, NATIVE_TOKEN, amount, sourceChainId, fromTxHash, block.timestamp);
    }

    // ============ Token Management Functions ============

    /**
     * @dev Add a supported token
     * @param token Address of the token to add
     */
    function addSupportedToken(address token) external onlyRole(TOKEN_MANAGER_ROLE) {
        require(!supportedTokens[token], "Token already supported");

        supportedTokens[token] = true;
        emit TokenAdded(token, block.timestamp);
    }

    /**
     * @dev Remove a supported token
     * @param token Address of the token to remove
     */
    function removeSupportedToken(address token) external onlyRole(TOKEN_MANAGER_ROLE) {
        require(supportedTokens[token], "Token not supported");

        supportedTokens[token] = false;
        emit TokenRemoved(token, block.timestamp);
    }

    // ============ Chain Management Functions ============

    /**
     * @dev Add a supported destination chain
     * @param chainId Chain ID to add
     */
    function addDestinationChain(uint256 chainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(chainId != 0, "Invalid chain ID");
        require(chainId != currentChainId, "Cannot add current chain as destination");
        require(!supportedDestinationChains[chainId], "Chain already supported");

        supportedDestinationChains[chainId] = true;
        emit DestinationChainAdded(chainId, block.timestamp);
    }

    /**
     * @dev Remove a supported destination chain
     * @param chainId Chain ID to remove
     */
    function removeDestinationChain(uint256 chainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(supportedDestinationChains[chainId], "Chain not supported");

        supportedDestinationChains[chainId] = false;
        emit DestinationChainRemoved(chainId, block.timestamp);
    }

    // ============ Admin Functions ============

    /**
     * @dev Pause the bridge
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!paused, "Already paused");
        paused = true;
        emit Paused(msg.sender, block.timestamp);
    }

    /**
     * @dev Unpause the bridge
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(paused, "Not paused");
        paused = false;
        emit Unpaused(msg.sender, block.timestamp);
    }

    /**
     * @dev Emergency withdraw tokens (only admin)
     * @param token Address of the token to withdraw
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Insufficient balance"
        );

        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, token, amount, block.timestamp);
    }

    /**
     * @dev Emergency withdraw native tokens (only admin)
     * @param amount Amount to withdraw
     */
    function emergencyWithdrawNative(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Native transfer failed");
        emit EmergencyWithdraw(msg.sender, NATIVE_TOKEN, amount, block.timestamp);
    }

    /**
     * @dev Deposit tokens to increase bridge liquidity
     * @param token Address of the token to deposit
     * @param amount Amount to deposit
     */
    function deposit(address token, uint256 amount) external onlyValidToken(token) {
        require(amount > 0, "Amount must be greater than 0");

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, token, amount, block.timestamp);
    }

    /**
     * @dev Deposit native tokens to increase bridge liquidity
     */
    function depositNative() external payable {
        require(supportedTokens[NATIVE_TOKEN], "Native token not supported");
        require(msg.value > 0, "Amount must be greater than 0");

        emit Deposit(msg.sender, NATIVE_TOKEN, msg.value, block.timestamp);
    }

    /**
     * @dev Receive function to accept native token deposits
     */
    receive() external payable {
        // Accept native token transfers
    }

    // ============ Fee Management Functions ============

    /**
     * @dev Set fee rate (only admin)
     * @param _feeRate New fee rate in basis points (100 = 1%)
     */
    function setFeeRate(uint256 _feeRate) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRate <= MAX_FEE_RATE, "Fee rate exceeds maximum");

        uint256 oldFeeRate = feeRate;
        feeRate = _feeRate;

        emit FeeRateUpdated(oldFeeRate, _feeRate, block.timestamp);
    }

    /**
     * @dev Set fee recipient address (only admin)
     * @param _feeRecipient New fee recipient address
     */
    function setFeeRecipient(address _feeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Invalid fee recipient");

        address oldRecipient = feeRecipient;
        feeRecipient = _feeRecipient;

        emit FeeRecipientUpdated(oldRecipient, _feeRecipient, block.timestamp);
    }

    /**
     * @dev Withdraw collected fees (only admin)
     * @param token Address of the token to withdraw fees for (use address(0) for native)
     */
    function withdrawFees(address token) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(feeRecipient != address(0), "Fee recipient not set");

        uint256 feeAmount = collectedFees[token];
        require(feeAmount > 0, "No fees to withdraw");

        collectedFees[token] = 0;

        if (token == NATIVE_TOKEN) {
            (bool success, ) = payable(feeRecipient).call{value: feeAmount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20(token).safeTransfer(feeRecipient, feeAmount);
        }

        emit FeeWithdrawn(token, feeRecipient, feeAmount, block.timestamp);
    }

    /**
     * @dev Withdraw collected fees to a specific address (only admin)
     * @param token Address of the token to withdraw fees for (use address(0) for native)
     * @param recipient Address to send fees to
     */
    function withdrawFeesTo(address token, address recipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipient != address(0), "Invalid recipient");

        uint256 feeAmount = collectedFees[token];
        require(feeAmount > 0, "No fees to withdraw");

        collectedFees[token] = 0;

        if (token == NATIVE_TOKEN) {
            (bool success, ) = payable(recipient).call{value: feeAmount}("");
            require(success, "Native transfer failed");
        } else {
            IERC20(token).safeTransfer(recipient, feeAmount);
        }

        emit FeeWithdrawn(token, recipient, feeAmount, block.timestamp);
    }

    /**
     * @dev Calculate fee for a given amount
     * @param amount Amount to calculate fee for
     * @return Fee amount
     */
    function calculateFee(uint256 amount) public view returns (uint256) {
        if (feeRate == 0) {
            return 0;
        }
        return (amount * feeRate) / 10000;
    }

    /**
     * @dev Calculate net amount after fee deduction
     * @param amount Gross amount
     * @return Net amount after fee
     */
    function calculateNetAmount(uint256 amount) external view returns (uint256) {
        uint256 fee = calculateFee(amount);
        return amount - fee;
    }

    // ============ View Functions ============

    /**
     * @dev Check if a transaction has been processed
     * @param fromTxHash Transaction hash to check
     * @return bool True if processed, false otherwise
     */
    function isProcessed(bytes32 fromTxHash) external view returns (bool) {
        return processedTransactions[fromTxHash];
    }

    /**
     * @dev Get the bridge balance for a specific token
     * @param token Address of the token (use address(0) for native token)
     * @return Balance of tokens in the bridge
     */
    function getBridgeBalance(address token) external view returns (uint256) {
        if (token == NATIVE_TOKEN) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    /**
     * @dev Get the locked balance for a user and token
     * @param token Address of the token
     * @param user Address of the user
     * @return Locked balance
     */
    function getLockedBalance(address token, address user) external view returns (uint256) {
        return lockedBalances[token][user];
    }

    /**
     * @dev Check if a token is supported
     * @param token Address of the token
     * @return bool True if supported
     */
    function isTokenSupported(address token) external view returns (bool) {
        return supportedTokens[token];
    }

    /**
     * @dev Check if a destination chain is supported
     * @param chainId Chain ID to check
     * @return bool True if supported
     */
    function isDestinationChainSupported(uint256 chainId) external view returns (bool) {
        return supportedDestinationChains[chainId];
    }

    /**
     * @dev Get current chain ID
     * @return Current chain ID
     */
    function getChainId() external view returns (uint256) {
        return currentChainId;
    }

    /**
     * @dev Get collected fees for a token
     * @param token Address of the token
     * @return Collected fee amount
     */
    function getCollectedFees(address token) external view returns (uint256) {
        return collectedFees[token];
    }

    /**
     * @dev Get fee configuration
     * @return _feeRate Current fee rate in basis points
     * @return _feeRecipient Current fee recipient address
     * @return _maxFeeRate Maximum allowed fee rate
     */
    function getFeeConfig() external view returns (
        uint256 _feeRate,
        address _feeRecipient,
        uint256 _maxFeeRate
    ) {
        return (feeRate, feeRecipient, MAX_FEE_RATE);
    }
}
