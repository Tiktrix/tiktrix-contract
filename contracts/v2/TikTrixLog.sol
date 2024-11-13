// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.8.0/contracts/access/AccessControl.sol";
import "./TikTrixGame.sol";

contract tTikTrixLog is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    TikTrix public tikTrixGame; 

    event GamePlayed(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameEnded(uint256 indexed gameSeq, uint256 indexed memberSeq);
    event GameLiked(uint256 indexed gameSeq, uint256 indexed memberSeq);

    constructor(address tikTrixGameAddress) {
        tikTrixGame = TikTrix(tikTrixGameAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function grantAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(ADMIN_ROLE, account);
    }

    function revokeAdminRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(ADMIN_ROLE, account);
    }

    function gamePlay(uint256 gameSeq, uint256 memberSeq) external {
        require(tikTrixGame.isGameExists(gameSeq), "Game does not exist");  // 참조 변경

        emit GamePlayed(gameSeq, memberSeq);
    }

    function gameEnd(uint256 gameSeq, uint256 memberSeq) external {
        require(tikTrixGame.isGameExists(gameSeq), "Game does not exist");  // 참조 변경

        emit GameEnded(gameSeq, memberSeq);
    }

    function gameLike(uint256 gameSeq, uint256 memberSeq) external {
        require(tikTrixGame.isGameExists(gameSeq), "Game does not exist");  // 참조 변경

        emit GameLiked(gameSeq, memberSeq);
    }

}
