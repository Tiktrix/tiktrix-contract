// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TokenPaymaster is IPaymaster, Ownable, AccessControl {
    IEntryPoint public immutable entryPoint;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public userGasLimits;
    
    constructor(IEntryPoint _entryPoint) Ownable(msg.sender) {
        entryPoint = _entryPoint;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, account);
    }

    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external virtual override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Sender not EntryPoint");
        require(userGasLimits[userOp.sender] >= maxCost, "Gas limit exceeded");
        
        return (abi.encode(userOp.sender), 0);
    }

    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external override {
        require(msg.sender == address(entryPoint), "Sender not EntryPoint");
        
        address sender = abi.decode(context, (address));
        userGasLimits[sender] -= actualGasCost;
    }

    function addSupportedToken(address token) external onlyRole(ADMIN_ROLE) {
        supportedTokens[token] = true;
    }

    function setUserGasLimit(address user, uint256 limit) external onlyRole(ADMIN_ROLE) {
        userGasLimits[user] = limit;
    }

    function deposit() public payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function withdrawTo(address payable to, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(to, amount);
    }

    function getDeposit() public view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    function existsUserGasLimit(address user) external view returns (bool) {
        return userGasLimits[user] > 0;
    }
}
