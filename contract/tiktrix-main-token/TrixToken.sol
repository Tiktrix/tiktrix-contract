// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TrixToken
 * @dev Fixed-supply ERC-20 token with metadata and contractURI support.
 */
contract TrixToken is ERC20, Ownable {
    uint8 private constant _decimals = 18;

    string private _contractURI;
    /**
     * @dev Constructor
     * @param name_ Token name (e.g., "Tiktrix Token")
     * @param symbol_ Token symbol (e.g., "TTRX")
     * @param initialSupply_ Token supply without decimals (e.g., 1_000_000_000)
     * @param contractURI_ IPFS metadata for the collection (contractURI)
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply_,
        string memory contractURI_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        uint256 supplyWithDecimals = initialSupply_ * 10 ** uint256(_decimals);
        _mint(msg.sender, supplyWithDecimals);
        _contractURI = contractURI_;
    }

    /**
     * @dev Returns the token's metadata URI (token-level metadata)
     */
    function tokenURI() external view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev Returns the contract-level metadata URI (OpenSea uses this for collection display)
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev Returns token decimals (default 18)
     */
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }
}