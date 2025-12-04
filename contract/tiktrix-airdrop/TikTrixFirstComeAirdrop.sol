// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "../vesting/token/ERC20/IERC20.sol";
import {SafeERC20} from "../vesting/token/ERC20/utils/SafeERC20.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TikTrixFirstComeAirdrop is PermissionsEnumerable, ContractMetadata {
    address public owner;
    address public deployer;

    using SafeERC20 for IERC20;
    uint256 public airdropAmount;
    uint256 public totalClaimed;
    uint256 public maxClaim;
    IERC20 private immutable _token;

    mapping(address => bool) public hasClaimed;

    event AirdropClaimed(address indexed claimer, uint256 amount);
    event EmergencyWithdrawn(uint256 amount, address indexed to);

    constructor(string memory _contractURI, address _deployer, address tokenAddress, uint256 _airdropAmount, uint256 _maxClaim) {
        require(tokenAddress != address(0), "Invalid token");
        _token = IERC20(tokenAddress);
        owner = msg.sender;
        airdropAmount = _airdropAmount;
        maxClaim = _maxClaim;

        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function getAirdropAmount() external view returns (uint256) {
        return airdropAmount;
    }

    function getMaxClaim() external view returns (uint256) {
        return maxClaim;
    }

    function getRemainingClaim() external view returns (uint256) {
        return maxClaim - totalClaimed;
    }

    function claim() external {
        require(!hasClaimed[msg.sender], "Already claimed");
        require(totalClaimed < maxClaim, "Airdrop ended");
        require(_token.balanceOf(address(this)) >= airdropAmount, "Insufficient contract balance");

        hasClaimed[msg.sender] = true;
        totalClaimed++;

        _token.safeTransfer(msg.sender, airdropAmount);
        emit AirdropClaimed(msg.sender, airdropAmount);
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
