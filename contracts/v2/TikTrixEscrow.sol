// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";

// 커스텀 인터페이스로 mint 함수 추가
interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract TikTrixEscrow is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    IERC20Mintable public entToken;
    IERC20Mintable public rptToken;

    struct MemberInfo {
        uint256 memberSeq;
    }

    struct ChallengeScore {
        uint256 gameSeq;
        uint256 memberSeq;
        uint256 tokenAmount;
        uint256 score;
        bool exists;
    }

    mapping(uint256 => MemberInfo) public memberInfos;
    uint256[] public memberIds; // Array to track registered member IDs

    mapping(uint256 => mapping(uint256 => mapping(uint256 => ChallengeScore))) public challengeScores;

    event MemberRegistered(uint256 memberSeq, uint256 tokenAmount);
    event ChallengeRegisterd(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 tokenAmount);
    event RankScoreUpdateNormal(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    event RankScoreUpdateChallenge(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    event PrizesDistributed(address[] recipients, uint256[] tokenAmounts);

    constructor(address entTokenAddress, address rptTokenAddress) {
        entToken = IERC20Mintable(entTokenAddress);
        rptToken = IERC20Mintable(rptTokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    function setTokens(address entTokenAddress, address rptTokenAddress) external onlyRole(ADMIN_ROLE) {
        entToken = IERC20Mintable(entTokenAddress);
        rptToken = IERC20Mintable(rptTokenAddress);
    }

    function memberRegister(uint256 memberSeq, address mintAddress, uint256 tokenAmount) external onlyRole(ADMIN_ROLE) {
        require(memberInfos[memberSeq].memberSeq == 0, "Member already registered");

        memberInfos[memberSeq] = MemberInfo({
            memberSeq: memberSeq
        });
        memberIds.push(memberSeq);

        entToken.mint(mintAddress, tokenAmount);

        emit MemberRegistered(memberSeq, tokenAmount);
    }

    function challengeRegister(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 tokenAmount
    ) external {
        require(!challengeScores[yyyymmdd][gameSeq][memberSeq].exists, "Challenge already exists for this member, date, and game");

        uint256 allowance = entToken.allowance(msg.sender, address(this));
        require(allowance >= tokenAmount, "Insufficient token allowance");

        uint256 balance = entToken.balanceOf(msg.sender);
        require(balance >= tokenAmount, "Insufficient token balance");

        require(entToken.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        challengeScores[yyyymmdd][gameSeq][memberSeq] = ChallengeScore({
            gameSeq: gameSeq,
            memberSeq: memberSeq,
            tokenAmount: tokenAmount,
            score: 0,
            exists: true
        });

        emit ChallengeRegisterd(yyyymmdd, gameSeq, memberSeq, tokenAmount);
    }

    function rankScoreUpdateNormal(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
       
        emit RankScoreUpdateNormal(yyyymmdd, gameSeq, memberSeq, newScore);
    }

    function rankScoreUpdateChallenge(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
        require(challengeScores[yyyymmdd][gameSeq][memberSeq].exists, "Challenge does not exist");

        if (newScore > challengeScores[yyyymmdd][gameSeq][memberSeq].score) {
            challengeScores[yyyymmdd][gameSeq][memberSeq].score = newScore;
        }

        emit RankScoreUpdateChallenge(yyyymmdd, gameSeq, memberSeq, newScore);
    }

    function distributePrizes(address[] calldata recipients, uint256[] calldata tokenAmounts) external onlyRole(ADMIN_ROLE) {
        require(recipients.length == tokenAmounts.length, "Recipients and token amounts length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            try rptToken.mint(recipients[i], tokenAmounts[i]) {
                // Mint succeeded
            } catch {
                revert("Minting failed for recipient");
            }
        }

        emit PrizesDistributed(recipients, tokenAmounts);
    }

    function getMemberInfo(uint256 memberSeq) external view returns (MemberInfo memory) {
        require(memberInfos[memberSeq].memberSeq > 0, "Member does not exist");
        return memberInfos[memberSeq];
    }

    function getChallengeScore(uint256 yyyymmdd, uint256 gameSeq, uint256 memberSeq) external view returns (ChallengeScore memory) {
        require(challengeScores[yyyymmdd][gameSeq][memberSeq].exists, "Challenge score does not exist");
        return challengeScores[yyyymmdd][gameSeq][memberSeq];
    }

}
