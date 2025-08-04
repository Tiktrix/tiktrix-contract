// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {VestingWalletUpgradeable} from "./VestingWalletUpgradeable.sol";

/**
 * @title VestingWalletFactory
 * @dev Factory contract to deploy VestingWallet proxies for testing
 */
contract VestingWalletFactory is Ownable {
    address public immutable vestingImplementation;
    address public deployer;

    event VestingWalletCreated(
        address indexed vestingWallet,
        address indexed deployer,
        address indexed token,
        uint64 startTimestamp
    );

    event ImplementationUpgraded(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    constructor() Ownable(msg.sender) {
        // Deploy the implementation contract
        vestingImplementation = address(new VestingWalletUpgradeable());
    }

    /**
     * @dev Deploy a new vesting wallet proxy
     */
    function createVestingWalletTest(
        string memory contractURI,
        address beneficiary,
        address tokenAddress,
        uint64 startTimestamp
    ) external returns (address) {
        require(beneficiary != address(0), "Beneficiary cannot be zero");
        require(tokenAddress != address(0), "Token address cannot be zero");

        // Encode the initializer function call
        bytes memory initData = abi.encodeWithSelector(
            VestingWalletUpgradeable.initialize.selector,
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
            deployer,
            tokenAddress,
            startTimestamp
        );

        return address(proxy);
    }

    /**
     * @dev Upgrade a specific vesting wallet to a new implementation
     */
    function upgradeVestingWalletTest(
        address vestingWallet,
        address newImplementation
    ) external onlyOwner {
        require(vestingWallet != address(0), "Vesting wallet cannot be zero");
        require(
            newImplementation != address(0),
            "Implementation cannot be zero"
        );

        VestingWalletUpgradeable(vestingWallet).upgradeToAndCall(
            newImplementation,
            ""
        );

        emit ImplementationUpgraded(vestingImplementation, newImplementation);
    }

    function getImplementation() external view returns (address) {
        return vestingImplementation;
    }

    /**
     * @dev Get vesting wallet details
     */
    function getVestingWalletDetails(
        address vestingWallet
    )
        external
        view
        returns (
            address beneficiary,
            address token,
            uint256 start,
            uint256 end,
            uint256 released,
            uint256 releasable
        )
    {
        VestingWalletUpgradeable wallet = VestingWalletUpgradeable(
            vestingWallet
        );

        beneficiary = wallet.beneficiary();
        token = address(wallet.token());
        start = wallet.start();
        end = wallet.end();
        released = wallet.released();
        releasable = wallet.releasable();
    }
}
