// SPDX-License-Identifier: MIT
// TikTrix-Game 1.0.1
pragma solidity ^0.8.26;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TikTrixGame is PermissionsEnumerable, Multicall, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    address public deployer;

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
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function gameRegister(uint256 gameSeq, uint256 memberSeq) external onlyRole(FACTORY_ROLE) {
        require(!gameInfos[gameSeq].exists, "Game already exist");

        gameInfos[gameSeq] = GameInfo({
            gameSeq: gameSeq,
            memberSeq: memberSeq,
            exists: true
        });

        emit GameRegistered(gameSeq, memberSeq);
    }

    function gameUpdate(uint256 gameSeq) external onlyRole(FACTORY_ROLE) {
        require(gameInfos[gameSeq].exists, "Game does not exist");

        emit GameUpdated(gameSeq);
    }

    function gameDelete(uint256 gameSeq) external onlyRole(FACTORY_ROLE) {
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

