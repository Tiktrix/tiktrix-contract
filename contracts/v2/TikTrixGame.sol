// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract TikTrixGame is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct GameInfo {
        uint256 gameSeq;
        uint256 memberSeq;
        bool exists;
    }

    mapping(uint256 => GameInfo) public gameInfos;

    event GameRegistered(uint256 gameSeq, uint256 memberSeq);
    event GameUpdated(uint256 gameSeq);
    event GameDeleted(uint256 indexed gameSeq);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, account);
    }

    function gameRegister(uint256 gameSeq, uint256 memberSeq) external onlyRole(ADMIN_ROLE) {
        require(!gameInfos[gameSeq].exists, "Game already exist");

        gameInfos[gameSeq] = GameInfo({
            gameSeq: gameSeq,
            memberSeq: memberSeq,
            exists: true
        });

        emit GameRegistered(gameSeq, memberSeq);
    }

    function gameUpdate(uint256 gameSeq) external onlyRole(ADMIN_ROLE) {
        require(gameInfos[gameSeq].exists, "Game does not exist");

        emit GameUpdated(gameSeq);
    }

    function gameDelete(uint256 gameSeq) external onlyRole(ADMIN_ROLE) {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        delete gameInfos[gameSeq];
        emit GameDeleted(gameSeq);
    }

    function getGameInfo(uint256 gameSeq) external view returns (GameInfo memory) {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        return gameInfos[gameSeq];
    }

    function isGameExists(uint256 gameSeq) external view returns (bool) {
        return gameInfos[gameSeq].exists;
    }

}

