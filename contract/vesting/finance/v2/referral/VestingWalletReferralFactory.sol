// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VestingWalletReferralUpgradeable} from "./VestingWalletReferralUpgradeable.sol";

contract VestingWalletReferralFactory is Ownable {
    address public immutable vestingImplementation;

    event VestingWalletCreated(
        address indexed vestingWallet,
        address indexed beneficiary,
        address indexed token,
        uint64 startTimestamp
    );

    event ImplementationUpgraded(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    constructor() Ownable(msg.sender) {
        // Deploy the implementation contract
        vestingImplementation = address(new VestingWalletReferralUpgradeable());
    }

    function createVestingWallet(
        string memory contractURI,
        address beneficiary,
        address tokenAddress,
        uint64 startTimestamp
    ) external returns (address) {
        require(beneficiary != address(0), "Beneficiary cannot be zero");
        require(tokenAddress != address(0), "Token address cannot be zero");

        // Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            VestingWalletReferralUpgradeable.initialize.selector,
            contractURI,
            msg.sender,
            beneficiary,
            tokenAddress,
            startTimestamp
        );

        // Deploy the proxy
        ERC1967Proxy proxy = new ERC1967Proxy(vestingImplementation, initData);

        emit VestingWalletCreated(
            address(proxy),
            beneficiary,
            tokenAddress,
            startTimestamp
        );

        return address(proxy);
    }

    function upgradeVestingWallet(
        address vestingWallet,
        address newImplementation
    ) external onlyOwner {
        require(vestingWallet != address(0), "Vesting wallet cannot be zero");
        require(
            newImplementation != address(0),
            "Implementation cannot be zero"
        );

        VestingWalletReferralUpgradeable(vestingWallet).upgradeToAndCall(
            newImplementation,
            ""
        );

        emit ImplementationUpgraded(vestingImplementation, newImplementation);
    }

    function getImplementation() external view returns (address) {
        return vestingImplementation;
    }
}
