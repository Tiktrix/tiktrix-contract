// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TikTrixGame is ERC721, Ownable {
    // 게임 정보 구조체
    struct GameInfo {
        uint256 developerSeq;  // 개발사 고유 번호
        uint256 gameSeq;       // 게임 고유 번호
        string title;          // 게임 제목
    }

    // 토큰 ID와 게임 정보를 매핑
    mapping(uint256 => GameInfo) private gameInfos;

    // 현재 토큰 ID
    uint256 private currentTokenId = 0;

    // 이벤트: 게임이 등록될 때 발생
    event GameRegistered(uint256 tokenId, uint256 developerSeq, uint256 gameSeq, string title);

    // ERC721과 Ownable 생성자에 필요한 인자를 전달
    constructor() ERC721("TikTrixGame", "TIKTRIXGAME") Ownable(msg.sender) {}

    // 게임 등록 함수
    function register(uint256 developerSeq, uint256 gameSeq, string memory title) public onlyOwner returns (uint256) {
        currentTokenId++;

        // 게임 정보 저장
        gameInfos[currentTokenId] = GameInfo({
            developerSeq: developerSeq,
            gameSeq: gameSeq,
            title: title
        });

        // ERC721 토큰 발행
        _mint(msg.sender, currentTokenId);

        // 이벤트 발생
        emit GameRegistered(currentTokenId, developerSeq, gameSeq, title);

        return currentTokenId;
    }

    // 게임 정보 조회 함수
    function getInfo(uint256 tokenId) public view returns (uint256 developerSeq, uint256 gameSeq, string memory title) {
        require(bytes(gameInfos[tokenId].title).length > 0, "GameRegistry: Query for nonexistent token");

        GameInfo memory game = gameInfos[tokenId];
        return (game.developerSeq, game.gameSeq, game.title);
    }
}
