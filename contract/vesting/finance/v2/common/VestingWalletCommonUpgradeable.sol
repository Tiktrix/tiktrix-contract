// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

/**
 * @title VestingWalletCommonUpgradeable
 * @dev Upgradeable vesting wallet contract for common vesting with fixed monthly releases
 */
contract VestingWalletCommonUpgradeable is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PermissionsEnumerable,
    ContractMetadata
{
    using SafeERC20 for IERC20;

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public deployer;
    address public beneficiary;

    event ERC20Released(
        address indexed token,
        address indexed beneficiary,
        uint256 amount
    );
    event BeneficiaryChanged(
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );

    IERC20 private token;
    uint256 private released;
    uint64 private start;

    // Vesting schedule parameters
    uint64 public interval;
    uint64 public totalPhases;

    // Fixed amount per phase: 989,583.33333333 tokens (18 decimals)
    uint256 public amountPerPhase;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract (replaces constructor for upgradeable contracts)
     */
    function initialize(
        string memory _contractURI,
        address _deployer,
        address _beneficiary,
        address _token,
        uint64 _interval,
        uint64 _totalPhases,
        uint256 _amountPerPhase,
        uint64 _start
    ) public initializer {
        require(_token != address(0), "Token address cannot be zero");
        require(_beneficiary != address(0), "Beneficiary cannot be zero");
        require(_deployer != address(0), "Deployer cannot be zero");
        require(_interval > 0, "Interval must be greater than 0");
        require(_totalPhases > 0, "Total phases must be greater than 0");
        require(_amountPerPhase > 0, "Amount per phase must be greater than 0");
        require(_start > 0, "Start must be greater than 0");

        __Context_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        beneficiary = _beneficiary;
        token = IERC20(_token);
        interval = _interval;
        totalPhases = _totalPhases;
        amountPerPhase = _amountPerPhase;
        start = _start;

        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(FACTORY_ROLE, _deployer);
        _setupRole(UPGRADER_ROLE, _deployer);
    }

    /**
     * @dev Authorize upgrade (only UPGRADER_ROLE can upgrade)
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function _canSetContractURI() internal view override returns (bool) {
        return
            msg.sender == deployer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function end() public view returns (uint256) {
        return start + (interval * totalPhases);
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released;
    }

    /**
     * @dev Release vested tokens to the beneficiary
     */
    function release() external onlyRole(FACTORY_ROLE) {
        uint256 amount = releasable();
        require(amount > 0, "No tokens to release");

        released += amount;
        emit ERC20Released(address(token), beneficiary, amount);
        token.safeTransfer(beneficiary, amount);
    }

    /**
     * @dev Calculate vested amount at given timestamp
     */
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        if (timestamp < start) return 0;

        uint64 elapsed = timestamp - start;
        uint64 phase = elapsed / interval;

        if (phase > totalPhases) {
            phase = totalPhases;
        }

        return amountPerPhase * phase;
    }
}
