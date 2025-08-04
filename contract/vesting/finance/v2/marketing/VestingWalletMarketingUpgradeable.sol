// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract VestingWalletMarketingUpgradeable is
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

    event ERC20Released(
        address indexed token,
        address indexed beneficiary,
        uint256 amount
    );

    IERC20Upgradeable private _token;
    uint256 private _released;
    uint64 private _start;

    // Vesting schedule parameters
    uint64 private constant INTERVAL = 30 days;
    uint64 private constant TOTAL_PHASES = 120;

    // Fixed amount per phase: 3,166,666.66666667 tokens (18 decimals)
    uint256 private constant AMOUNT_PER_PHASE = 3_166_666_666666670000000000;

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

        _beneficiary = beneficiaryAddress;
        _token = IERC20Upgradeable(tokenAddress);
        _start = startTimestamp;

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

    function token() public view returns (IERC20Upgradeable) {
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

    function release() external onlyRole(FACTORY_ROLE) {
        uint256 amount = releasable();
        require(amount > 0, "No tokens to release");

        _released += amount;
        emit ERC20Released(address(_token), beneficiary(), amount);
        _token.safeTransfer(beneficiary(), amount);
    }

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
