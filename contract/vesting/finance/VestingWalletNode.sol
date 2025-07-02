// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "../token/ERC20/IERC20.sol";
import {SafeERC20} from "../token/ERC20/utils/SafeERC20.sol";
import {Address} from "../utils/Address.sol";
import {Context} from "../utils/Context.sol";
import {Ownable} from "../access/Ownable.sol";

import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract VestingWalletNode is Context, Ownable, PermissionsEnumerable, ContractMetadata {
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    address public deployer;
    address public _beneficiary;

    using SafeERC20 for IERC20;

    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);

    IERC20 private immutable _token;
    uint256 private _released;
    mapping(address token => uint256) private _erc20Released;
    uint64 private immutable _start;
    
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

    constructor(string memory _contractURI, address _deployer, address beneficiary, address tokenAddress, uint64 startTimestamp) payable Ownable(beneficiary) {
        require(tokenAddress != address(0), "Token address cannot be zero");
        _token = IERC20(tokenAddress);
        _start = startTimestamp;
        _beneficiary = beneficiary;

        _setupContractURI(_contractURI);
        deployer = _deployer;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(FACTORY_ROLE, msg.sender);
    }

    function _canSetContractURI() internal view override returns (bool) {
        return msg.sender == deployer;
    }

    receive() external payable virtual {}

    function start() public view virtual returns (uint256) {
        return _start;
    }

    function end() public view virtual returns (uint256) {
        return start() + (INTERVAL * TOTAL_PHASES);
    }

    function token() public view returns (IERC20) {
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
        emit ERC20Released(address(_token), amount);
        _token.safeTransfer(owner(), amount);
    }

    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _customVesting(timestamp);
    }

    function _customVesting(uint64 timestamp) internal view returns (uint256) {
        if (timestamp < _start) return 0;

        uint64 elapsed = timestamp - _start;
        uint64 phase = elapsed / INTERVAL;
        if (phase >= TOTAL_PHASES) {
            phase = TOTAL_PHASES - 1;
        }

        uint64 p = phase + 1;
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

        for (uint256 i = 0; i < 10; i++) {
            uint64 start = uint64(i * 12);
            if (p <= start) break;

            uint64 count = p > start + 12 ? 12 : p - start;
            vested += phaseAmounts[i] * count;
        }

        return vested;
    }
}
