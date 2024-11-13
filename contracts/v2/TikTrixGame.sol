// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";

contract TikTrix is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct GameInfo {
        uint256 developerSeq;
        uint256 gameSeq;
        string title;
        bool exists;
    }

    mapping(uint256 => GameInfo) public gameInfos;

    event GameRegistered(uint256 developerSeq, uint256 gameSeq, string title);
    event GameUpdated(uint256 developerSeq, uint256 gameSeq, string title);
    event GameDeleted(uint256 indexed gameSeq);

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

    function getGameInfo(uint256 gameSeq) external view returns (GameInfo memory) {
        require(gameInfos[gameSeq].exists, "Game does not exist");
        return gameInfos[gameSeq];
    }

}
