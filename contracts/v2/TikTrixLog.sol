// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";
import "./TikTrixGame.sol";

contract TikTrixLog is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event GamePlayed(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameEnded(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameLiked(uint256 indexed gameSeq, uint256 indexed memberSeq);

    event MemberRegistered(uint256 memberSeq, uint256 tokenAmount);
    event ChallengeRegistred(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 tokenAmount);
    event RankScoreUpdateNormal(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    event RankScoreUpdateChallenge(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    event PrizesDistributed(address[] recipients, uint256[] tokenAmounts);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    // Game 관련 로그 함수들
    function logGamePlay(uint256 gameSeq, uint256 memberSeq) external onlyRole(ADMIN_ROLE) {
        emit GamePlayed(gameSeq, memberSeq);
    }

    function logGameEnd(uint256 gameSeq, uint256 memberSeq) external onlyRole(ADMIN_ROLE) {
        emit GameEnded(gameSeq, memberSeq);
    }

    function logGameLike(uint256 gameSeq, uint256 memberSeq) external onlyRole(ADMIN_ROLE) {
        emit GameLiked(gameSeq, memberSeq);
    }

    function logMemberRegistered(uint256 memberSeq, uint256 tokenAmount) external onlyRole(ADMIN_ROLE) {
        emit MemberRegistered(memberSeq, tokenAmount);
    }

    function logChallengeRegistred(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 tokenAmount
    ) external onlyRole(ADMIN_ROLE) {
        emit ChallengeRegistred(yyyymmdd, gameSeq, memberSeq, tokenAmount);
    }

    function logRankScoreUpdateNormal(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
        emit RankScoreUpdateNormal(yyyymmdd, gameSeq, memberSeq, newScore);
    }

    function logRankScoreUpdateChallenge(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
        emit RankScoreUpdateChallenge(yyyymmdd, gameSeq, memberSeq, newScore);
    }

    function logPrizesDistributed(
        address[] calldata recipients,
        uint256[] calldata tokenAmounts
    ) external onlyRole(ADMIN_ROLE) {
        emit PrizesDistributed(recipients, tokenAmounts);
    }
}
