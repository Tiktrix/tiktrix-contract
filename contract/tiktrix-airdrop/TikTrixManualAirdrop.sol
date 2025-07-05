// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "../vesting/token/ERC20/IERC20.sol";
import {SafeERC20} from "../vesting/token/ERC20/utils/SafeERC20.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TikTrixManualAirdrop is PermissionsEnumerable, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    address public owner;
    address public deployer;

    using SafeERC20 for IERC20;
    uint256 public airdropAmount;
    IERC20 private immutable _token;

    mapping(address => bool) public hasClaimed;

    event AirdropSend(address indexed recipient, uint256 amount);
    event EmergencyWithdrawn(uint256 amount, address indexed to);

    constructor(
        string memory _contractURI,
        address _deployer,
        address tokenAddress,
        uint256 _airdropAmount
    ) {
        require(tokenAddress != address(0), "Invalid token");
        _token = IERC20(tokenAddress);
        owner = msg.sender;
        airdropAmount = _airdropAmount;

        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function getAirdropAmount() external view returns (uint256) {
        return airdropAmount;
    }

    function setAirdropAmount(
        uint256 _airdropAmount
    ) external onlyRole(FACTORY_ROLE) {
        airdropAmount = _airdropAmount;
    }

    function multiSendAmount(
        address[] calldata recipients
    ) external onlyRole(FACTORY_ROLE) {
        require(recipients.length > 0, "No recipients");
        require(recipients.length <= 1000, "Too many recipients");

        uint256 totalAmount = airdropAmount * recipients.length;
        require(
            _token.balanceOf(address(this)) >= totalAmount,
            "Insufficient balance"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            _token.safeTransfer(recipients[i], airdropAmount);
            emit AirdropSend(recipients[i], airdropAmount);
        }
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");

        require(msg.sender == owner, "Not owner");
        uint256 remaining = _token.balanceOf(address(this));
        _token.safeTransfer(owner, remaining);

        emit EmergencyWithdrawn(balance, msg.sender);
    }
}
