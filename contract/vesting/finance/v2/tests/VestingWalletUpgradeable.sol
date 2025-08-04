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
 * @title VestingWalletUpgradeable
 * @dev Upgradeable vesting wallet contract for advisors with fixed 5 minutes releases
 */
contract VestingWalletUpgradeable is
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
    address public _beneficiary;

    event ERC20Released(address indexed token, uint256 amount);
    event BeneficiaryChanged(
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );

    IERC20 private _token;
    uint256 private _released;
    uint64 private _start;

    // 5 minutes
    uint64 private constant INTERVAL = 5 minutes;
    uint64 private constant TOTAL_PHASES = 96;

    // Fixed amount per phase: 989,583.33333333 tokens (18 decimals)
    uint256 private constant AMOUNT_PER_PHASE = 989_583_333333330000000000;

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
        address beneficiary,
        address tokenAddress,
        uint64 startTimestamp
    ) public initializer {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(beneficiary != address(0), "Beneficiary cannot be zero");
        require(_deployer != address(0), "Deployer cannot be zero");

        __Context_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _beneficiary = beneficiary;
        _token = IERC20(tokenAddress);
        _start = startTimestamp;

        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(FACTORY_ROLE, _deployer);
        _setupRole(FACTORY_ROLE, 0x6055A65b9A27F0B2Ffdb444DaA59cc46301Da720);
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

    function token() public view returns (IERC20) {
        return _token;
    }

    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    function start() public view returns (uint256) {
        return _start;
    }

    function end() public view returns (uint256) {
        return start() + (INTERVAL * TOTAL_PHASES);
    }

    function released() public view returns (uint256) {
        return _released;
    }

    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Release vested tokens to the beneficiary
     */
    function release() external onlyRole(FACTORY_ROLE) {
        uint256 amount = releasable();
        require(amount > 0, "No tokens to release");

        _released += amount;
        emit ERC20Released(address(_token), amount);
        _token.safeTransfer(_beneficiary, amount);
    }

    /**
     * @dev Calculate vested amount at given timestamp
     */
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        if (timestamp < _start) return 0;

        uint64 elapsed = timestamp - _start;
        uint64 phase = elapsed / INTERVAL;

        if (phase > TOTAL_PHASES) {
            phase = TOTAL_PHASES;
        }

        return AMOUNT_PER_PHASE * phase;
    }
}
