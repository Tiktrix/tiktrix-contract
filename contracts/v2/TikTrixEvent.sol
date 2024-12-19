// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";

contract TikTrixEvent is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct MemberInfo {
        uint256 memberSeq;
    }

    mapping(uint256 => MemberInfo) public memberInfos;
    uint256[] public memberIds;

    event MemberRegistered(uint256 memberSeq);
    event RankScoreUpdateNoraml(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    
    event GamePlayed(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameEnded(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameLiked(uint256 indexed gameSeq, uint256 indexed memberSeq);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    function memberRegister(uint256 memberSeq) external onlyRole(ADMIN_ROLE) {
        require(memberInfos[memberSeq].memberSeq == 0, "Member already registered");

        memberInfos[memberSeq] = MemberInfo({
            memberSeq: memberSeq
        });
        memberIds.push(memberSeq);

        emit MemberRegistered(memberSeq);
    }

    function rankScoreUpdateNormal(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(ADMIN_ROLE) {
       
        emit RankScoreUpdateNoraml(yyyymmdd, gameSeq, memberSeq, newScore);
    }

    function gamePlay(uint256 gameSeq, uint256 memberSeq) external {

        emit GamePlayed(gameSeq, memberSeq);
    }

    function gameEnd(uint256 gameSeq, uint256 memberSeq) external {

        emit GameEnded(gameSeq, memberSeq);
    }

    function gameLike(uint256 gameSeq, uint256 memberSeq) external {

        emit GameLiked(gameSeq, memberSeq);
    }

}
