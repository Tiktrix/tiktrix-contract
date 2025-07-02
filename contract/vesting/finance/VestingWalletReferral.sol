// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {SafeERC20} from "../token/ERC20/utils/SafeERC20.sol";
import {Context} from "../utils/Context.sol";
import {Ownable} from "../access/Ownable.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract VestingWalletReferral is Context, Ownable, PermissionsEnumerable, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    address public deployer;

    using SafeERC20 for IERC20;

    event ERC20Released(address indexed token, uint256 amount);

    IERC20 private immutable _token;
    uint256 private _released;
    uint64 private immutable _start;

    // Vesting schedule parameters
    uint64 private constant INTERVAL = 30 days;
    uint64 private constant TOTAL_PHASES = 120;

    // Fixed amount per phase: 791,666.66666667 tokens (18 decimals)
    uint256 private constant AMOUNT_PER_PHASE = 791_666_666666670000000;

    constructor(string memory _contractURI, address _deployer, address beneficiary, address tokenAddress, uint64 startTimestamp) Ownable(beneficiary) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        _token = IERC20(tokenAddress);
        _start = startTimestamp;

        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    function token() public view returns (IERC20) {
        return _token;
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
        emit ERC20Released(address(_token), amount);
        _token.safeTransfer(owner(), amount);
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
