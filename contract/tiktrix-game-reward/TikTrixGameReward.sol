// SPDX-License-Identifier: MIT
// TikTrix-Game-Reward 1.0.1
pragma solidity ^0.8.26;

import "@thirdweb-dev/contracts/base/ERC20Base.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

// ITokenERC20 인터페이스 정의
interface ITokenERC20 {
    function mintTo(address to, uint256 amount) external;
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract TikTrixGameReward is PermissionsEnumerable, Multicall, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    address public deployer;

    ITokenERC20 public rewardToken;
    
    mapping(uint256 => mapping(uint256 => bool)) public isRewardDistributed;
    
    event ManualReward(address recipient, uint256 tokenAmount);
    event ManualRewardBatch(address[] recipients, uint256[] tokenAmounts);
    event DailyGameRankingReward(
        uint256 indexed yyyymmdd,
        uint256 indexed gameSeq,
        address[] recipients,
        uint256[] tokenAmounts
    );

    constructor(string memory _contractURI, address _deployer, address rewardTokenAddress) {
        _setupContractURI(_contractURI);
        deployer = _deployer;
        rewardToken = ITokenERC20(rewardTokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function setRewardToken(address rewardTokenAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardToken = ITokenERC20(rewardTokenAddress);
    }

    function manualReward(address recipient, uint256 tokenAmount) external onlyRole(FACTORY_ROLE) {
        rewardToken.mintTo(recipient, tokenAmount);

        emit ManualReward(recipient, tokenAmount);
    }

    function batchManualReward(address[] calldata recipients, uint256[] calldata tokenAmounts) external onlyRole(FACTORY_ROLE) {
        require(recipients.length == tokenAmounts.length, "Recipients and token amounts length mismatch");
        require(recipients.length > 0, "Recipients array is empty");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            rewardToken.mintTo(recipients[i], tokenAmounts[i]);
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
            rewardToken.mintTo(recipients[i], tokenAmounts[i]);
        }

        isRewardDistributed[yyyymmdd][gameSeq] = true;

        emit DailyGameRankingReward(yyyymmdd, gameSeq, recipients, tokenAmounts);
    }

    function checkRewardDistributed(uint256 yyyymmdd, uint256 gameSeq) external view returns (bool) {
        return isRewardDistributed[yyyymmdd][gameSeq];
    }
}