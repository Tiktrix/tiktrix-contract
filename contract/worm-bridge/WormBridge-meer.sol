// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

/**
 * @title WormBridge
 * @dev Bridge contract for locking WORM tokens on MeerChain
 * One-way bridge: MeerChain (lock) -> Monad (mint via AA)
 */
contract WormBridge is PermissionsEnumerable, ContractMetadata, Multicall, ReentrancyGuard {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    address public deployer;

    IERC20 public wormToken;

    mapping(address => uint256) public lockedBalances;
    uint256 public totalLocked;

    event Lock(
        address indexed user,
        address indexed monadAddress,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev Constructor
     * @param _contractURI Metadata URI for the contract
     * @param _wormToken Address of the WORM token contract
     */
    constructor(string memory _contractURI, address _wormToken) {
        require(_wormToken != address(0), "Invalid token address");
        wormToken = IERC20(_wormToken);
        deployer = msg.sender;
        _setupContractURI(_contractURI);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    /**
     * @dev Lock WORM tokens in the bridge
     * @param monadAddress The destination address on Monad chain (AA wallet)
     * @param amount Amount of tokens to lock
     */
    function lock(address monadAddress, uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(monadAddress != address(0), "Invalid Monad address");

        // Transfer tokens from user to bridge
        require(
            wormToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        lockedBalances[msg.sender] += amount;
        totalLocked += amount;

        emit Lock(msg.sender, monadAddress, amount, block.timestamp);
    }

    /**
     * @dev Get locked balance of a user
     * @param user Address of the user
     * @return Locked balance of the user
     */
    function getLockedBalance(address user) external view returns (uint256) {
        return lockedBalances[user];
    }

    /**
     * @dev Get the total balance of WORM tokens in the bridge
     * @return Balance of WORM tokens in the bridge
     */
    function getBridgeBalance() external view returns (uint256) {
        return wormToken.balanceOf(address(this));
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
    }
}

