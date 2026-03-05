// SPDX-License-Identifier: MIT
// Tiktrix-Node-RewardManager-ERC20 1.0.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

contract TikTrixNodeRewardManagerERC20 is
    PermissionsEnumerable,
    Multicall,
    ContractMetadata,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    IERC20 public rewardToken;
    address public daoAddress;
    address public deployer;
    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

    uint256 public totalMinted;
    uint256 public totalEarlyClaimedPenalty;

    uint256 private constant WEEK = 7 days;

    struct RewardInfo {
        bool isRegistered;
        bool isClaimed;
        uint256 amount;
        uint256 calculationTime;
    }

    mapping(address => mapping(uint256 => RewardInfo)) public rewards;

    event RewardUpdated(address indexed user, uint256 indexed week, uint256 amount, uint256 calculationTime);
    event RewardClaimed(address indexed user, uint256 indexed week, uint256 amount, uint256 fee);
    event RewardDeposited(uint256 amount);
    event RewardWithdrawn(uint256 amount);
    event DaoNodeFeeMinted(uint256 amount);
    event EmergencyWithdrawn(uint256 amount, address to);
    event RewardTokenChanged(address indexed oldToken, address indexed newToken);

    constructor(
        string memory _contractURI,
        address _deployer,
        address _daoAddress,
        address _rewardToken
    ) {
        require(_daoAddress != address(0), "Invalid DAO address");
        require(_rewardToken != address(0), "Invalid reward token address");

        deployer = _deployer;
        daoAddress = _daoAddress;
        rewardToken = IERC20(_rewardToken);

        _setupRole(DEFAULT_ADMIN_ROLE, _deployer);
        _setupContractURI(_contractURI);
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    function setRewardToken(address _rewardToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_rewardToken != address(0), "Invalid reward token address");
        address oldToken = address(rewardToken);
        rewardToken = IERC20(_rewardToken);
        emit RewardTokenChanged(oldToken, _rewardToken);
    }

    function updateReward(address user, uint256 week, uint256 amount, uint256 calculationTime) external onlyRole(FACTORY_ROLE) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");

        RewardInfo storage reward = rewards[user][week];
        require(!reward.isRegistered, "Reward already registered");

        rewards[user][week] = RewardInfo({
            isRegistered: true,
            isClaimed: false,
            amount: amount,
            calculationTime: calculationTime
        });
        emit RewardUpdated(user, week, amount, calculationTime);
    }

    function updateRewardBatch(
        address[] calldata _users,
        uint256[] calldata _weeks,
        uint256[] calldata _amounts,
        uint256[] calldata _calculationTimes
    ) external onlyRole(FACTORY_ROLE) {
        require(
            _users.length == _weeks.length &&
            _users.length == _amounts.length &&
            _users.length == _calculationTimes.length,
            "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            uint256 week = _weeks[i];
            uint256 amount = _amounts[i];
            uint256 calculationTime = _calculationTimes[i];

            require(user != address(0), "Invalid user address");
            RewardInfo storage reward = rewards[user][week];
            require(!reward.isRegistered, "Reward already registered");

            rewards[user][week] = RewardInfo({
                isRegistered: true,
                isClaimed: false,
                amount: amount,
                calculationTime: calculationTime
            });

            emit RewardUpdated(user, week, amount, calculationTime);
        }
    }

    function _processRewardClaim(address user, uint256 week) internal returns (uint256 claimAmount, uint256 earlyClaimPenalty) {
        RewardInfo storage reward = rewards[user][week];
        require(reward.isRegistered, "Reward not registered");
        require(!reward.isClaimed, "Reward already claimed");
        require(rewardToken.balanceOf(address(this)) >= reward.amount, "Insufficient contract balance");

        (uint256 calculatedClaimAmount, uint256 calculatedPenalty,) = calculateRewardAmount(user, week);
        require(calculatedClaimAmount > 0, "No claimable amount available");

        reward.isClaimed = true;
        claimAmount = calculatedClaimAmount;
        earlyClaimPenalty = calculatedPenalty;
        totalMinted += claimAmount;

        if (earlyClaimPenalty > 0) {
            totalEarlyClaimedPenalty += earlyClaimPenalty;
        }

        if (earlyClaimPenalty > 0) {
            rewardToken.safeTransfer(daoAddress, earlyClaimPenalty);
        }

        if (claimAmount > 0) {
            rewardToken.safeTransfer(user, claimAmount);
        }

        emit RewardClaimed(user, week, claimAmount, earlyClaimPenalty);
    }

    function claimReward(uint256 week) external nonReentrant {
        _processRewardClaim(msg.sender, week);
    }

    function claimRewardAgent(address user, uint256 week) external nonReentrant onlyRole(FACTORY_ROLE) {
        require(user != address(0), "Invalid user address");
        _processRewardClaim(user, week);
    }

    function claimRewardAgentBatch(address[] calldata _users, uint256[] calldata _weeks) external nonReentrant onlyRole(FACTORY_ROLE) {
        require(_users.length == _weeks.length, "Input arrays length mismatch");

        for (uint256 i = 0; i < _users.length; i++) {
            address user = _users[i];
            require(user != address(0), "Invalid user address");
            _processRewardClaim(user, _weeks[i]);
        }
    }

    function mintDaoNodeFee(uint256 amount) external onlyRole(FACTORY_ROLE) {
        require(amount > 0, "Amount must be greater than 0");
        require(rewardToken.balanceOf(address(this)) >= amount, "Insufficient contract balance");

        rewardToken.safeTransfer(daoAddress, amount);
        totalEarlyClaimedPenalty += amount;

        emit DaoNodeFeeMinted(amount);
    }

    function getRewardInfoBatch(address user, uint256[] calldata _weeks) external view returns (RewardInfo[] memory) {
        require(user != address(0), "Invalid user address");
        uint256 length = _weeks.length;
        RewardInfo[] memory batchRewards = new RewardInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            batchRewards[i] = rewards[user][_weeks[i]];
        }

        return batchRewards;
    }

    function getRewardClaimableBatch(address user, uint256[] calldata _weeks) external view returns (bool[] memory){
        require(user != address(0), "Invalid user address");
        uint256 length = _weeks.length;
        bool[] memory claimableStatuses = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            RewardInfo storage reward = rewards[user][_weeks[i]];
            if (reward.isRegistered && !reward.isClaimed && block.timestamp >= reward.calculationTime + 4 weeks) {
                claimableStatuses[i] = true;
            } else {
                claimableStatuses[i] = false;
            }
        }

        return claimableStatuses;
    }

    function getRewardInfo(address user, uint256 week) external view returns (RewardInfo memory) {
        return rewards[user][week];
    }

    function getTotalMintedAmount() external view returns (uint256) {
        return totalMinted + totalEarlyClaimedPenalty;
    }

    function depositToken(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardDeposited(amount);
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = rewardToken.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");

        rewardToken.safeTransfer(msg.sender, balance);

        emit EmergencyWithdrawn(balance, msg.sender);
    }

    function getContractBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function calculateRewardAmount(address user, uint256 week) public view returns (
        uint256 claimableAmount,
        uint256 earlyClaimPenalty,
        uint256 totalAmount
    ) {
        RewardInfo storage reward = rewards[user][week];
        require(reward.isRegistered, "Reward not registered");
        require(!reward.isClaimed, "Reward already claimed");

        uint256 timeElapsed = block.timestamp - reward.calculationTime;
        uint256 rewardAmount = reward.amount;
        totalAmount = rewardAmount;

        if (timeElapsed >= 4 * WEEK) {
            earlyClaimPenalty = 0;
        } else if (timeElapsed >= 3 * WEEK) {
            earlyClaimPenalty = (rewardAmount * 25) / 100;
        } else if (timeElapsed >= 2 * WEEK) {
            earlyClaimPenalty = (rewardAmount * 50) / 100;
        } else if (timeElapsed >= WEEK) {
            earlyClaimPenalty = (rewardAmount * 75) / 100;
        } else {
            return (0, 0, 0);
        }

        claimableAmount = rewardAmount - earlyClaimPenalty;

        return (claimableAmount, earlyClaimPenalty, totalAmount);
    }
}
