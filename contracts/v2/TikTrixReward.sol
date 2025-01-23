// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract TikTrixReward is PermissionsEnumerable, Multicall {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    IERC20Mintable public rewardToken;
    
    mapping(uint256 => mapping(uint256 => bool)) public isRewardDistributed;
    
    event ManualReward(address recipient, uint256 tokenAmount);
    event ManualRewardBatch(address[] recipients, uint256[] tokenAmounts);
    event DailyGameRankingReward(
        uint256 indexed yyyymmdd,
        uint256 indexed gameSeq,
        address[] recipients,
        uint256[] tokenAmounts
    );

    constructor(address rewardTokenAddress) {
        rewardToken = IERC20Mintable(rewardTokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function setRewardToken(address rewardTokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardToken = IERC20Mintable(rewardTokenAddress);
    }

    function manualReward(address recipient, uint256 tokenAmount) external onlyRole(FACTORY_ROLE) {
        rewardToken.mint(recipient, tokenAmount);

        emit ManualReward(recipient, tokenAmount);
    }

    function batchManualReward(address[] calldata recipients, uint256[] calldata tokenAmounts) external onlyRole(FACTORY_ROLE) {
        require(recipients.length == tokenAmounts.length, "Recipients and token amounts length mismatch");
        require(recipients.length > 0, "Recipients array is empty");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            rewardToken.mint(recipients[i], tokenAmounts[i]);
        }

        emit ManualRewardBatch(recipients, tokenAmounts);
    }

    function dailyGameRankingReward(
        uint256 yyyymmdd,
        uint256 gameSeq,
        address[] calldata recipients,
        uint256[] calldata tokenAmounts
    ) external onlyRole(FACTORY_ROLE) {
        require(!isRewardDistributed[yyyymmdd][gameSeq], "Reward already distributed for this game");
        require(recipients.length == tokenAmounts.length, "Recipients and token amounts length mismatch");
        require(recipients.length > 0, "Recipients array is empty");

        for (uint256 i = 0; i < recipients.length; i++) {
            rewardToken.mint(recipients[i], tokenAmounts[i]);
        }

        isRewardDistributed[yyyymmdd][gameSeq] = true;

        emit DailyGameRankingReward(yyyymmdd, gameSeq, recipients, tokenAmounts);
    }

    function checkRewardDistributed(uint256 yyyymmdd, uint256 gameSeq) external view returns (bool) {
        return isRewardDistributed[yyyymmdd][gameSeq];
    }
}
