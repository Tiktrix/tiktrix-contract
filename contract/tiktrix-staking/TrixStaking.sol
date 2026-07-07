// SPDX-License-Identifier: MIT
// TrixStaking 1.0.0
//
// Based on MiraclePlay DualRewardAPRStaking v1.5.2 (internal contract).
// Changes from the original:
//  - Native-coin staking -> ERC-20 (TRIX) staking via SafeERC20 (stake = reward token)
//  - reward2 (mintable ERC-20) removed: TRIX is fixed-supply, single reward
//  - Fixed APR accrual kept, but APR changes are checkpointed globally
//    (cumulative bps-seconds) so a rate change never applies retroactively
//  - Two-step withdrawal: requestWithdraw() -> withdrawalDelay (24h) -> withdraw().
//    Requested amounts stop accruing rewards immediately
//  - Minimum stake amount enforced (position must be 0 or >= minStakeAmount)
//  - stakers[] enumeration, adminUnstakeAll, confiscateFromUser, POOL_ENDED removed
//    (off-chain indexing uses events; sunset = setApr(0) + setStakingPaused(true))
//  - ReentrancyGuard added, events added for every state change (backend sync
//    relies on them), admin reward recovery bounded to the excess reward pool
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";

contract TrixStaking is
    PermissionsEnumerable,
    ContractMetadata,
    Multicall,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    uint256 private constant BPS_DENOMINATOR = 10000;
    uint256 private constant YEAR_IN_SECONDS = 31536000;
    uint256 public constant MAX_OPEN_WITHDRAWAL_REQUESTS = 10;
    uint256 public constant MAX_APR_BPS = 10000; // 100%
    uint256 public constant MAX_WITHDRAWAL_DELAY = 30 days;

    IERC20 public immutable stakingToken; // TRIX (staking and reward token)
    address public deployer;

    uint256 public aprBps; // 300 = 3.00% (two decimal places, as in the original)
    uint256 public minStakeAmount;
    uint256 public withdrawalDelay;
    bool public stakingPaused;

    // Global APR checkpoint: sum of (aprBps * elapsed seconds) over time.
    // reward = stakedAmount * delta(cumBpsSeconds) / BPS_DENOMINATOR / YEAR_IN_SECONDS
    uint256 private cumulativeBpsSeconds;
    uint256 private lastAprCheckpointTime;

    uint256 public totalStaked;
    uint256 public totalPendingWithdrawal;
    uint256 public totalRewardReserved; // accrued-but-unclaimed (checkpointed)

    struct Staker {
        uint256 stakedAmount;
        uint256 rewardEarned; // checkpointed accrued reward
        uint256 cumBpsSecondsSnapshot;
    }
    mapping(address => Staker) public stakers;

    struct WithdrawalRequest {
        uint256 id; // globally unique, used by off-chain sync as the join key
        uint256 amount;
        uint256 releaseTime;
    }
    mapping(address => WithdrawalRequest[]) private _withdrawalRequests;
    uint256 private _nextRequestId = 1;

    event Staked(address indexed user, uint256 amount, uint256 totalUserStaked);
    event WithdrawalRequested(
        address indexed user,
        uint256 indexed requestId,
        uint256 amount,
        uint256 releaseTime
    );
    event WithdrawalCancelled(
        address indexed user,
        uint256 indexed requestId,
        uint256 amount
    );
    event Withdrawn(address indexed user, uint256 indexed requestId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardDeposited(address indexed from, uint256 amount);
    event RewardRecovered(address indexed to, uint256 amount);
    event AprUpdated(uint256 oldAprBps, uint256 newAprBps);
    event MinStakeAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event WithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event StakingPausedSet(bool paused);

    constructor(
        address _adminAddr,
        address _stakingToken,
        uint256 _aprBps,
        uint256 _minStakeAmount,
        uint256 _withdrawalDelay,
        string memory _contractURI
    ) {
        require(_adminAddr != address(0), "Invalid admin");
        require(_stakingToken != address(0), "Invalid token");
        require(_aprBps <= MAX_APR_BPS, "APR too high");
        require(_withdrawalDelay <= MAX_WITHDRAWAL_DELAY, "Delay too long");

        _setupRole(DEFAULT_ADMIN_ROLE, _adminAddr);
        deployer = _adminAddr;
        stakingToken = IERC20(_stakingToken);
        aprBps = _aprBps;
        minStakeAmount = _minStakeAmount;
        withdrawalDelay = _withdrawalDelay;
        lastAprCheckpointTime = block.timestamp;
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool) {
        return msg.sender == deployer;
    }

    // ============ Reward accounting ============

    function _currentCumBpsSeconds() private view returns (uint256) {
        return
            cumulativeBpsSeconds +
            aprBps *
            (block.timestamp - lastAprCheckpointTime);
    }

    modifier updateReward(address account) {
        uint256 cum = _currentCumBpsSeconds();
        Staker storage user = stakers[account];
        if (user.stakedAmount > 0) {
            uint256 newReward = (user.stakedAmount *
                (cum - user.cumBpsSecondsSnapshot)) /
                BPS_DENOMINATOR /
                YEAR_IN_SECONDS;
            user.rewardEarned += newReward;
            totalRewardReserved += newReward;
        }
        user.cumBpsSecondsSnapshot = cum;
        _;
    }

    // ============ User functions ============

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(!stakingPaused, "Staking is paused");
        require(amount > 0, "Must stake non-zero amount");

        Staker storage user = stakers[msg.sender];
        require(
            user.stakedAmount + amount >= minStakeAmount,
            "Below minimum stake"
        );

        user.stakedAmount += amount;
        totalStaked += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount, user.stakedAmount);
    }

    // Moves `amount` out of the reward-accruing position into a time-locked
    // withdrawal request. Intentionally NOT gated by stakingPaused: exits stay open.
    function requestWithdraw(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Must request non-zero amount");

        Staker storage user = stakers[msg.sender];
        require(user.stakedAmount >= amount, "Not enough balance");

        uint256 remaining = user.stakedAmount - amount;
        require(
            remaining == 0 || remaining >= minStakeAmount,
            "Remainder below minimum stake"
        );
        require(
            _withdrawalRequests[msg.sender].length < MAX_OPEN_WITHDRAWAL_REQUESTS,
            "Too many open requests"
        );

        user.stakedAmount = remaining;
        totalStaked -= amount;
        totalPendingWithdrawal += amount;

        uint256 requestId = _nextRequestId++;
        uint256 releaseTime = block.timestamp + withdrawalDelay;
        _withdrawalRequests[msg.sender].push(
            WithdrawalRequest({id: requestId, amount: amount, releaseTime: releaseTime})
        );

        emit WithdrawalRequested(msg.sender, requestId, amount, releaseTime);
    }

    // Re-stakes a pending withdrawal request.
    function cancelWithdrawalRequest(uint256 requestId)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        WithdrawalRequest[] storage requests = _withdrawalRequests[msg.sender];
        uint256 length = requests.length;

        for (uint256 i = 0; i < length; i++) {
            if (requests[i].id != requestId) continue;

            uint256 amount = requests[i].amount;
            Staker storage user = stakers[msg.sender];
            require(
                user.stakedAmount + amount >= minStakeAmount,
                "Below minimum stake"
            );

            requests[i] = requests[length - 1];
            requests.pop();

            user.stakedAmount += amount;
            totalStaked += amount;
            totalPendingWithdrawal -= amount;

            emit WithdrawalCancelled(msg.sender, requestId, amount);
            return;
        }
        revert("Request not found");
    }

    // Pays out every matured withdrawal request in one call.
    function withdraw() external nonReentrant {
        WithdrawalRequest[] storage requests = _withdrawalRequests[msg.sender];
        uint256 totalAmount = 0;

        for (uint256 i = requests.length; i > 0; i--) {
            WithdrawalRequest memory request = requests[i - 1];
            if (request.releaseTime > block.timestamp) continue;

            totalAmount += request.amount;
            requests[i - 1] = requests[requests.length - 1];
            requests.pop();

            emit Withdrawn(msg.sender, request.id, request.amount);
        }
        require(totalAmount > 0, "No withdrawable amount");

        totalPendingWithdrawal -= totalAmount;
        stakingToken.safeTransfer(msg.sender, totalAmount);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        Staker storage user = stakers[msg.sender];
        uint256 reward = user.rewardEarned;
        require(reward > 0, "No reward to claim");

        // Rewards can never be paid out of staked principal or pending withdrawals.
        uint256 rewardBalance = stakingToken.balanceOf(address(this)) -
            totalStaked -
            totalPendingWithdrawal;
        require(rewardBalance >= reward, "Insufficient reward pool");

        user.rewardEarned = 0;
        totalRewardReserved -= reward;

        stakingToken.safeTransfer(msg.sender, reward);
        emit RewardClaimed(msg.sender, reward);
    }

    // Anyone can top up the reward pool (same as the original addReward()).
    function depositReward(uint256 amount) external nonReentrant {
        require(amount > 0, "Must deposit non-zero amount");
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardDeposited(msg.sender, amount);
    }

    // ============ Views (consumed by staking-web3.service) ============

    function earned(address account) public view returns (uint256) {
        Staker memory user = stakers[account];
        if (user.stakedAmount == 0) return user.rewardEarned;
        return
            user.rewardEarned +
            (user.stakedAmount *
                (_currentCumBpsSeconds() - user.cumBpsSecondsSnapshot)) /
            BPS_DENOMINATOR /
            YEAR_IN_SECONDS;
    }

    function getStakeInfo(address account)
        external
        view
        returns (
            uint256 stakedAmount,
            uint256 pendingWithdrawalAmount,
            uint256 withdrawableAmount,
            uint256 earnedReward
        )
    {
        stakedAmount = stakers[account].stakedAmount;
        WithdrawalRequest[] memory requests = _withdrawalRequests[account];
        for (uint256 i = 0; i < requests.length; i++) {
            pendingWithdrawalAmount += requests[i].amount;
            if (requests[i].releaseTime <= block.timestamp) {
                withdrawableAmount += requests[i].amount;
            }
        }
        earnedReward = earned(account);
    }

    function getWithdrawalRequests(address account)
        external
        view
        returns (WithdrawalRequest[] memory)
    {
        return _withdrawalRequests[account];
    }

    // Reward pool that is not owed to anyone (principal, pending exits and
    // already-accrued rewards excluded). Saturates to 0 when accrued rewards
    // exceed the funded pool so monitoring reads a signal instead of a revert.
    function availableRewardBalance() public view returns (uint256) {
        uint256 owed = totalStaked + totalPendingWithdrawal + totalRewardReserved;
        uint256 balance = stakingToken.balanceOf(address(this));
        return balance > owed ? balance - owed : 0;
    }

    // Checkpointed reward liabilities in excess of the funded pool. True
    // liability can be slightly higher: lazy accrual means earned() amounts
    // not yet checkpointed are not counted here.
    function rewardDeficit() external view returns (uint256) {
        uint256 owed = totalStaked + totalPendingWithdrawal + totalRewardReserved;
        uint256 balance = stakingToken.balanceOf(address(this));
        return owed > balance ? owed - balance : 0;
    }

    // ============ Admin functions ============

    function setApr(uint256 newAprBps) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAprBps <= MAX_APR_BPS, "APR too high");
        // Checkpoint so the new rate only applies from now on.
        cumulativeBpsSeconds = _currentCumBpsSeconds();
        lastAprCheckpointTime = block.timestamp;

        emit AprUpdated(aprBps, newAprBps);
        aprBps = newAprBps;
    }

    function setMinStakeAmount(uint256 newMinStakeAmount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emit MinStakeAmountUpdated(minStakeAmount, newMinStakeAmount);
        minStakeAmount = newMinStakeAmount;
    }

    function setWithdrawalDelay(uint256 newWithdrawalDelay)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newWithdrawalDelay <= MAX_WITHDRAWAL_DELAY, "Delay too long");
        emit WithdrawalDelayUpdated(withdrawalDelay, newWithdrawalDelay);
        withdrawalDelay = newWithdrawalDelay;
    }

    function setStakingPaused(bool paused) external onlyRole(DEFAULT_ADMIN_ROLE) {
        stakingPaused = paused;
        emit StakingPausedSet(paused);
    }

    // Recovers only the excess reward pool. Principal, pending withdrawals and
    // accrued rewards can never be pulled by the admin.
    function recoverExcessReward(uint256 amount)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(amount > 0 && amount <= availableRewardBalance(), "Exceeds available");
        stakingToken.safeTransfer(msg.sender, amount);
        emit RewardRecovered(msg.sender, amount);
    }

    // Recovers tokens sent to this contract by mistake. The staking token is
    // blocked entirely so user funds and the reward pool stay untouchable here.
    function recoverERC20(address tokenAddress, uint256 amount)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(tokenAddress != address(stakingToken), "Cannot recover staking token");
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
    }
}
