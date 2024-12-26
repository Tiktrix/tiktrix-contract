// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";
import "./TikTrixEscrow.sol";

contract TikTrixScore is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    TikTrixEscrow public escrow;    
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) public highScores;
    
    event ScoreUpdated(
        uint256 baseDate, 
        uint256 gameSeq, 
        uint256 memberSeq, 
        uint256 newScore,
        uint256 previousScore
    );

    event RankScoreUpdateNoraml(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    
    constructor(address _escrowAddress) {
        escrow = TikTrixEscrow(_escrowAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    function rankScoreUpdateNormal(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
       
        emit RankScoreUpdateNoraml(yyyymmdd, gameSeq, memberSeq, newScore);
    }
    
    function rankScoreUpdateChallenge(
        uint256 baseDate,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
        (uint256 depositAmount, bool isReturned) = escrow.getDepositFee(baseDate, gameSeq, memberSeq);
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