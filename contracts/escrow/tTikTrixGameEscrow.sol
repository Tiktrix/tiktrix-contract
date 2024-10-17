// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";
import "../token/tRPTToken.sol";

contract tTikTrixGameEscrow is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    IERC20 public entToken;
    IERC20 public rptToken; 

    struct Challenge {
        uint256 gameSeq;
        uint256 memberSeq;
        uint256 tokenAmount;
        uint256 score;
        bool exists;
    }

    // mapping: 기준일자 => 게임 고유 번호 => 회원 번호 => 챌린지 정보
    mapping(uint256 => mapping(uint256 => mapping(uint256 => Challenge))) public challenges;

    constructor(address entTokenAddress, address rptTokenAddress) {
        entToken = IERC20(entTokenAddress);
        rptToken = IERC20(rptTokenAddress);  // 민팅 가능한 ERC20 토큰 설정
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);  // 계약 배포자는 기본 관리자
        _setupRole(ADMIN_ROLE, msg.sender);  // ADMIN_ROLE 역할 부여
    }

    // ADMIN_ROLE 부여 기능
    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    // ADMIN_ROLE 제거 기능
    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    // 챌린지 도전 기능
    function challenge(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 tokenAmount
    ) external {
        // 이미 챌린지가 존재하는지 확인
        require(!challenges[yyyymmdd][gameSeq][memberSeq].exists, "Challenge already exists for this member, date, and game");

        // 사용자가 컨트랙트에 대해 허용한 토큰 수량(allowance) 확인
        uint256 allowance = entToken.allowance(msg.sender, address(this));
        require(allowance >= tokenAmount, "Insufficient token allowance");

        // 사용자 지갑의 토큰 잔액 확인
        uint256 balance = entToken.balanceOf(msg.sender);
        require(balance >= tokenAmount, "Insufficient token balance");

        // 사용자 지갑에서 컨트랙트로 참여 토큰 전송
        require(entToken.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");

        // 챌린지 정보 저장
        challenges[yyyymmdd][gameSeq][memberSeq] = Challenge({
            gameSeq: gameSeq,
            memberSeq: memberSeq,
            tokenAmount: tokenAmount,
            score: 0,  // 스코어는 아직 없음
            exists: true
        });
    }

    // 챌린지 스코어 등록 기능 (관리자만 호출 가능)
    function registerScore(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
        require(challenges[yyyymmdd][gameSeq][memberSeq].exists, "Challenge does not exist");
        require(challenges[yyyymmdd][gameSeq][memberSeq].gameSeq == gameSeq, "Game sequence mismatch");

        // 기존 스코어보다 높은 경우에만 갱신
        if (newScore > challenges[yyyymmdd][gameSeq][memberSeq].score) {
            challenges[yyyymmdd][gameSeq][memberSeq].score = newScore;
        }
    }

    // 상금 분배 기능 (민팅 기반)
    function distributePrizes(address[] calldata recipients, uint256 tokenAmount) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < recipients.length; i++) {
            tRPT(address(rptToken)).mint(recipients[i], tokenAmount);  // 민팅하여 지급
        }
    }

    // 상금 분배 및 참여할 때 사용할 토큰 설정 기능
    function setTokens(address entTokenAddress, address rptTokenAddress) external onlyRole(ADMIN_ROLE) {
        entToken = IERC20(entTokenAddress);
        rptToken = IERC20(rptTokenAddress);
    }
}
