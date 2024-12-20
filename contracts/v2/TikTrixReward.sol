// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract TikTrixReward is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20Mintable public rewardToken;
    
    event DistributeReward(address recipient, uint256 tokenAmount);
    event MultiDistributeReward(address[] recipients, uint256[] tokenAmounts);

    constructor(address rewardTokenAddress) {
        rewardToken = IERC20Mintable(rewardTokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    function setRewardToken(address rewardTokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardToken = IERC20Mintable(rewardTokenAddress);
    }

    function distributeReward(address recipient, uint256 tokenAmount) external onlyRole(ADMIN_ROLE) {
        rewardToken.mint(recipient, tokenAmount);

        emit DistributeReward(recipient, tokenAmount);
    }

    function multiDistributeReward(address[] calldata recipients, uint256[] calldata tokenAmounts) external onlyRole(ADMIN_ROLE) {
        require(recipients.length == tokenAmounts.length, "Recipients and token amounts length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            rewardToken.mint(recipients[i], tokenAmounts[i]);
        }

        emit MultiDistributeReward(recipients, tokenAmounts);
    }
}
