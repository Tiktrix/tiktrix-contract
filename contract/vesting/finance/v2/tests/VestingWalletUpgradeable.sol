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

    address public _deployer; // Changed to internal for consistency
    address public _beneficiary;

    event ERC20Released(address indexed token, uint256 amount);
    event BeneficiaryChanged(
        address indexed oldBeneficiary,
        address indexed newBeneficiary
    );

    IERC20 private _token;
    uint256 public _released; // Changed to public for visibility
    uint256 private _start; // Changed to uint256 for consistency with block.timestamp

    uint64 public INTERVAL; // Made configurable
    uint64 public TOTAL_PHASES; // Made configurable

    uint256 public AMOUNT_PER_PHASE; // Made configurable

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the contract (replaces constructor for upgradeable contracts)
     */
    function initialize(
        string memory _contractURI,
        address deployerAddress, // Renamed for clarity
        address beneficiaryAddress,
        address tokenAddress,
        uint256 startTimestamp, // Changed to uint256
        uint64 interval, // Added for configurability
        uint64 totalPhases, // Added for configurability
        uint256 amountPerPhase // Added for configurability
    ) public initializer {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(beneficiaryAddress != address(0), "Beneficiary cannot be zero");
        require(deployerAddress != address(0), "Deployer cannot be zero");
        require(startTimestamp > 0, "Start timestamp must be greater than 0");
        require(interval > 0, "Interval must be greater than 0");
        require(totalPhases > 0, "Total phases must be greater than 0");
        require(amountPerPhase > 0, "Amount per phase must be greater than 0");

        __Context_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _beneficiary = beneficiaryAddress;
        _token = IERC20(tokenAddress);
        _start = startTimestamp;
        INTERVAL = interval;
        TOTAL_PHASES = totalPhases;
        AMOUNT_PER_PHASE = amountPerPhase;

        _setupContractURI(_contractURI);
        _deployer = deployerAddress; // Assigned to new internal variable
        _setupRole(DEFAULT_ADMIN_ROLE, deployerAddress);
        _setupRole(FACTORY_ROLE, deployerAddress); // Use deployerAddress for FACTORY_ROLE
        // Removed hardcoded address: _setupRole(FACTORY_ROLE, 0x6055A65b9A27F0B2Ffdb444DaA59cc46301Da720);
        _setupRole(UPGRADER_ROLE, deployerAddress);
    }

    /**
     * @dev Authorize upgrade (only UPGRADER_ROLE can upgrade)
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function _canSetContractURI() internal view override returns (bool) {
        return
            msg.sender == _deployer || hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
        return start() + (uint256(INTERVAL) * TOTAL_PHASES);
    }

    // `released()` is now public due to `_released` being public

    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - _released;
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
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        if (timestamp < _start) return 0;

        uint256 elapsed = timestamp - _start;
        uint256 phase = elapsed / INTERVAL;

        if (phase > TOTAL_PHASES) {
            phase = TOTAL_PHASES;
        }

        return AMOUNT_PER_PHASE * phase;
    }

    /**
     * @dev Emergency function to withdraw tokens to the contract owner.
     * Changed to owner() for clarity and consistency.
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 amount = _token.balanceOf(address(this));
        require(amount > 0, "No tokens to withdraw");
        _token.safeTransfer(owner(), amount);
    }
}


