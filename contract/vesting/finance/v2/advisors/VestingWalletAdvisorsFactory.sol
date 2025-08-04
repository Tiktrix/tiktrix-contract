// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VestingWalletAdvisorsUpgradeable} from "./VestingWalletAdvisorsUpgradeable.sol";

/**
 * @title VestingWalletAdvisorsFactory
 * @dev Factory contract to deploy VestingWalletAdvisors proxies
 */
contract VestingWalletAdvisorsFactory is Ownable {
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
        vestingImplementation = address(new VestingWalletAdvisorsUpgradeable());
    }

    /**
     * @dev Deploy a new vesting wallet proxy
     */
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
            VestingWalletAdvisorsUpgradeable.initialize.selector,
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

    /**
     * @dev Upgrade a specific vesting wallet to a new implementation
     */
    function upgradeVestingWallet(
        address vestingWallet,
        address newImplementation
    ) external onlyOwner {
        require(vestingWallet != address(0), "Vesting wallet cannot be zero");
        require(
            newImplementation != address(0),
            "Implementation cannot be zero"
        );

        VestingWalletAdvisorsUpgradeable(vestingWallet).upgradeToAndCall(
            newImplementation,
            ""
        );

        emit ImplementationUpgraded(vestingImplementation, newImplementation);
    }
}
