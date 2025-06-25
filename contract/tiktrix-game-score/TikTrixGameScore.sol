// SPDX-License-Identifier: MIT
// TikTrix-Game-Score 1.0.1
pragma solidity ^0.8.26;

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TikTrixGameScore is PermissionsEnumerable, Multicall, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    address public deployer;

    
    event RankScoreUpdateNoraml(uint256 indexed yyyymmdd, uint256 indexed gameSeq, uint256 indexed memberSeq, uint256 newScore);
    
    constructor(string memory _contractURI, address _deployer) {
        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function rankScoreUpdateNormal(
        uint256 yyyymmdd,
        uint256 gameSeq,
        uint256 memberSeq,
        uint256 newScore
    ) external onlyRole(FACTORY_ROLE) {
       
        emit RankScoreUpdateNoraml(yyyymmdd, gameSeq, memberSeq, newScore);
    }
    
}
