// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";
import "../../token/tENTToken.sol";
import "../../token/tRPTToken.sol";

contract tTikTrixGameEscrow is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    tENT public entToken;
    tRPT public rptToken;

    struct GameInfo {
        uint256 developerSeq;
        uint256 gameSeq;
        string title;
        bool exists;
    }

    struct ChallengeScore {
        uint256 gameSeq;
        uint256 memberSeq;
        uint256 tokenAmount;
        uint256 score;
        bool exists;
    }

    struct MemberInfo {
        uint256 memberSeq;
    }

    mapping(uint256 => mapping(uint256 => mapping(uint256 => ChallengeScore))) public challenges;
    mapping(uint256 => GameInfo) public gameInfos;
    mapping(uint256 => MemberInfo) public memberInfos;

    event ChallengeRegistred(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 tokenAmount);
    event RankScoreUpdateNoraml(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    event RankScoreUpdateChallenge(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    event PrizesDistributed(address[] recipients, uint256[] tokenAmounts);

    event GamePlayed(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameEnded(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameLiked(uint256 indexed gameSeq, uint256 indexed memberSeq);

    event GameRegistered(uint256 developerSeq, uint256 gameSeq, string title);
    event GameUpdated(uint256 developerSeq, uint256 gameSeq, string title);
    event GameDeleted(uint256 indexed gameSeq);
    event MemberRegistered(uint256 memberSeq, uint256 tokenAmount);

    constructor(address entTokenAddress, address rptTokenAddress) {
        entToken = tENT(entTokenAddress);
        rptToken = tRPT(rptTokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    function gameRegister(uint256 developerSeq, uint256 gameSeq, string memory title) external onlyRole(ADMIN_ROLE) {
        gameInfos[gameSeq] = GameInfo({
            developerSeq: developerSeq,
            gameSeq: gameSeq,
            title: title,
            exists: true
        });

        emit GameRegistered(developerSeq, gameSeq, title);
    }

    function gameUpdate(uint256 developerSeq, uint256 gameSeq, string memory title) external onlyRole(ADMIN_ROLE) {
        require(gameInfos[gameSeq].exists, "Game does not exist");

        GameInfo storage gameInfo = gameInfos[gameSeq];
        gameInfo.developerSeq = developerSeq;
        gameInfo.gameSeq = gameSeq;
        gameInfo.title = title;

        emit GameUpdated(developerSeq, gameSeq, title);
    }

    function gameDelete(uint256 gameSeq) external onlyRole(ADMIN_ROLE) {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        delete gameInfos[gameSeq];
        emit GameDeleted(gameSeq);
    }

    function registerMember(uint256 memberSeq, address mintAddress, uint256 tokenAmount) external onlyRole(ADMIN_ROLE) {
        require(memberInfos[memberSeq].memberSeq == 0, "Member already registered");

        memberInfos[memberSeq] = MemberInfo({
            memberSeq: memberSeq
        });

        entToken.mint(mintAddress, tokenAmount);

        emit MemberRegistered(memberSeq, tokenAmount);
    }

    function challengeRegister(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 tokenAmount
    ) external {
        require(!challenges[yyyymmdd][gameSeq][memberSeq].exists, "Challenge already exists for this member, date, and game");

        uint256 allowance = entToken.allowance(msg.sender, address(this));
        require(allowance >= tokenAmount, "Insufficient token allowance");

        uint256 balance = entToken.balanceOf(msg.sender);
        require(balance >= tokenAmount, "Insufficient token balance");

        require(entToken.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        challenges[yyyymmdd][gameSeq][memberSeq] = ChallengeScore({
            gameSeq: gameSeq,
            memberSeq: memberSeq,
            tokenAmount: tokenAmount,
            score: 0,
            exists: true
        });

        emit ChallengeRegistred(yyyymmdd, gameSeq, memberSeq, tokenAmount);
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
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
        require(challenges[yyyymmdd][gameSeq][memberSeq].exists, "Challenge does not exist");

        if (newScore > challenges[yyyymmdd][gameSeq][memberSeq].score) {
            challenges[yyyymmdd][gameSeq][memberSeq].score = newScore;
        }

        emit RankScoreUpdateChallenge(yyyymmdd, gameSeq, memberSeq, newScore);
    }

    function distributePrizes(address[] calldata recipients, uint256[] calldata tokenAmounts) external onlyRole(ADMIN_ROLE) {
        require(recipients.length == tokenAmounts.length, "Recipients and token amounts length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            rptToken.mint(recipients[i], tokenAmounts[i]);
        }

        emit PrizesDistributed(recipients, tokenAmounts);
    }

    function setTokens(address entTokenAddress, address rptTokenAddress) external onlyRole(ADMIN_ROLE) {
        entToken = tENT(entTokenAddress);
        rptToken = tRPT(rptTokenAddress);
    }

    function gamePlay(uint256 gameSeq, uint256 memberSeq) external {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        emit GamePlayed(gameSeq, memberSeq);
    }

    function gameEnd(uint256 gameSeq, uint256 memberSeq) external {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        emit GameEnded(gameSeq, memberSeq);
    }

    function gameLike(uint256 gameSeq, uint256 memberSeq) external {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        emit GameLiked(gameSeq, memberSeq);
    }

    function getGameInfo(uint256 gameSeq) external view returns (GameInfo memory) {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        return gameInfos[gameSeq];
    }

    function getMemberInfo(uint256 memberSeq) external view returns (MemberInfo memory) {
        require(memberInfos[memberSeq].memberSeq > 0, "Member does not exist");
        return memberInfos[memberSeq];
    }
}
