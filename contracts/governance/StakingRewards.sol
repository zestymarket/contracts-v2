// SPDX-License-Identifier: MIT

// Adapted from synthetix staking rewards

pragma solidity ^0.7.6;

import "../utils/SafeMath.sol";
import "../utils/ReentrancyGuard.sol";
import "../utils/Math.sol";
import "../interfaces/IStakingRewards.sol";
import "../interfaces/IERC20.sol";
import "./RewardsRecipient.sol";

contract StakingRewards is IStakingRewards, RewardsRecipient, ReentrancyGuard {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    address private _rewardsTokenAddress;
    address private _stakingTokenAddress;
    IERC20 private _rewardsToken;
    IERC20 private _stakingToken;
    uint256 private periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address owner_,
        address rewardsDistributor_,
        address rewardsToken_,
        address stakingToken_
    ) RewardsRecipient(owner_, rewardsDistributor_) {
        _rewardsTokenAddress = rewardsToken_;
        _stakingTokenAddress = stakingToken_;
        _rewardsToken = IERC20(rewardsToken_);
        _stakingToken = IERC20(stakingToken_);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view override returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view override returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view override returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view override returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function rewardsToken() external view override returns (address) {
        return _rewardsTokenAddress;
    }

    function stakingToken() external view override returns (address) {
        return _stakingTokenAddress;
    }

    function rewardsDistributor() external view override(IStakingRewards, RewardsRecipient) returns (address) {
        return _rewardsDistributor;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external override nonReentrant updateReward(msg.sender) {
        require(
            amount > 0, 
            "StakingRewards::stake: Cannot stake 0"
        );
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        require(
            _stakingToken.transferFrom(msg.sender, address(this), amount),
            "StakingRewards::stake: Transfer of staking token failed, check if sufficient allowance is provided"
        );
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public override nonReentrant updateReward(msg.sender) {
        require(
            amount > 0, 
            "StakingRewards::withdraw: Cannot withdraw 0"
        );
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        require(
            _stakingToken.transfer(msg.sender, amount),
            "StakingRewards::withdraw: Transfer of staking token failed"
        );
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public override nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            require(
                _rewardsToken.transfer(msg.sender, reward),
                "StakingRewards::getReward: Transfer of reward token failed"
            );
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external override {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external override onlyRewardsDistributor updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = _rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    // End rewards emission earlier
    function updatePeriodFinish(uint timestamp) external onlyOwner updateReward(address(0)) {
        periodFinish = timestamp;
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(
            tokenAddress != _stakingTokenAddress, 
            "StakingRewards::recoverERC20: Cannot withdraw staking token"
        );
        require(
            IERC20(tokenAddress).transfer(owner(), tokenAmount), 
            "StakingRewards::recoverERC20: Transfer of ERC20 failed"
        );
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
}