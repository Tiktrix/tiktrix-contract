// SPDX-License-Identifier: MIT
// TikTrix-Game-Score 1.0.1
pragma solidity ^0.8.26;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "../tiktrix-game-challenge/TikTrixGameChallenge.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TikTrixGameScore is PermissionsEnumerable, Multicall, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    address public deployer;

    TikTrixGameChallenge public challenge;    
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) public highScores;
    
    event ScoreUpdated(
        uint256 baseDate, 
        uint256 gameSeq, 
        uint256 memberSeq, 
        uint256 newScore,
        uint256 previousScore
    );

    event RankScoreUpdateNoraml(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    
    constructor(address _challengeAddress) {
        challenge = TikTrixGameChallenge(_challengeAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function rankScoreUpdateNormal(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(FACTORY_ROLE) {
       
        emit RankScoreUpdateNoraml(yyyymmdd, gameSeq, memberSeq, newScore);
    }
    
    function rankScoreUpdateChallenge(
        uint256 baseDate,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(FACTORY_ROLE) {
        (uint256 depositAmount, bool isReturned) = challenge.getDepositFee(baseDate, gameSeq, memberSeq);
        require(depositAmount > 0, "No deposit found for this challenge");
        require(!isReturned, "Deposit has already been returned");        

        uint256 currentHighScore = highScores[baseDate][gameSeq][memberSeq];
        
        if(newScore > currentHighScore) {
            highScores[baseDate][gameSeq][memberSeq] = newScore;
        }
        
        emit ScoreUpdated(baseDate, gameSeq, memberSeq, newScore, currentHighScore);
    }
    
    function getHighScore(uint256 baseDate, uint256 gameSeq, uint256 memberSeq) 
        external 
        view 
        returns (uint256)
    {
        return highScores[baseDate][gameSeq][memberSeq];
    }
}
