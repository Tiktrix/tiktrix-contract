// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract VestingWalletNodeUpgradeable is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PermissionsEnumerable,
    ContractMetadata
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address public deployer;
    address public _beneficiary;

    event EtherReleased(uint256 amount);
    event ERC20Released(
        address indexed token,
        address indexed beneficiary,
        uint256 amount
    );

    IERC20Upgradeable private _token;
    uint256 private _released;
    mapping(address token => uint256) private _erc20Released;
    uint64 private _start;

    uint64 private constant INTERVAL = 30 days;
    uint64 private constant TOTAL_PHASES = 120;

    uint256 private constant AMOUNT_PHASE1 = 12152777750000000000000000;
    uint256 private constant AMOUNT_PHASE2 = 10937499916666670000000000;
    uint256 private constant AMOUNT_PHASE3 = 9843749916666667000000000;
    uint256 private constant AMOUNT_PHASE4 = 8859374916666667000000000;
    uint256 private constant AMOUNT_PHASE5 = 7973437416666667000000000;
    uint256 private constant AMOUNT_PHASE6 = 7176093666666667000000000;
    uint256 private constant AMOUNT_PHASE7 = 6458484333333330000000000;
    uint256 private constant AMOUNT_PHASE8 = 5812635916666667000000000;
    uint256 private constant AMOUNT_PHASE9 = 5231372333333330000000000;
    uint256 private constant AMOUNT_PHASE10 = 4721240500000000000000000;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _contractURI,
        address _deployer,
        address beneficiaryAddress,
        address tokenAddress,
        uint64 startTimestamp
    ) public initializer {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(beneficiaryAddress != address(0), "Beneficiary cannot be zero");
        require(_deployer != address(0), "Deployer cannot be zero");

        __Context_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _token = IERC20Upgradeable(tokenAddress);
        _start = startTimestamp;
        _beneficiary = beneficiaryAddress;

        _setupContractURI(_contractURI);
        deployer = _deployer;

        // Setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupRole(FACTORY_ROLE, _deployer);
        _setupRole(FACTORY_ROLE, 0x6055A65b9A27F0B2Ffdb444DaA59cc46301Da720);
        _setupRole(UPGRADER_ROLE, _deployer);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function start() public view virtual returns (uint256) {
        return _start;
    }

    function end() public view virtual returns (uint256) {
        return start() + (INTERVAL * TOTAL_PHASES);
    }

    function token() public view returns (IERC20Upgradeable) {
        return _token;
    }

    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    function released() public view virtual returns (uint256) {
        return _released;
    }

    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    function release() external onlyRole(FACTORY_ROLE) {
        uint256 amount = releasable();
        require(amount > 0, "No tokens to release");

        _released += amount;
        emit ERC20Released(address(_token), beneficiary(), amount);
        _token.safeTransfer(beneficiary(), amount);
    }

    function vestedAmount(
        uint64 timestamp
    ) public view virtual returns (uint256) {
        return _customVesting(timestamp);
    }

    function _customVesting(uint64 timestamp) public view returns (uint256) {
        if (timestamp < _start) return 0;

        uint64 elapsed = timestamp - _start;
        uint64 currentPhase = elapsed / INTERVAL;

        // Cap at total phases
        if (currentPhase >= TOTAL_PHASES) {
            currentPhase = TOTAL_PHASES - 1;
        }

        uint256 vested = 0;

        uint256[10] memory phaseAmounts = [
            AMOUNT_PHASE1,
            AMOUNT_PHASE2,
            AMOUNT_PHASE3,
            AMOUNT_PHASE4,
            AMOUNT_PHASE5,
            AMOUNT_PHASE6,
            AMOUNT_PHASE7,
            AMOUNT_PHASE8,
            AMOUNT_PHASE9,
            AMOUNT_PHASE10
        ];

        // Calculate vested amount up to currentPhase (inclusive)
        for (uint256 i = 0; i < 10; i++) {
            uint64 phaseStart = uint64(i * 12); // Phase group starts at month i*12
            uint64 phaseEnd = phaseStart + 11; // Phase group ends at month i*12+11

            if (currentPhase < phaseStart) {
                // Haven't reached this phase group yet
                break;
            }

            if (currentPhase >= phaseEnd) {
                // Completed this entire phase group (12 months)
                vested += phaseAmounts[i] * 12;
            } else {
                // Partially completed this phase group
                uint64 monthsInThisPhase = currentPhase - phaseStart + 1;
                vested += phaseAmounts[i] * monthsInThisPhase;
            }
        }

        return vested;
    }
}
