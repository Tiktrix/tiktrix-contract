// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

contract TikTrixEvent is PermissionsEnumerable, Multicall {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

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
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function memberRegister(uint256 memberSeq) external onlyRole(FACTORY_ROLE) {
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
    ) external onlyRole(FACTORY_ROLE) {
       
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

