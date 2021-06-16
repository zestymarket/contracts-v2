// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

// Adapted from synthetix RewardsDistribution

import "../utils/Ownable.sol";
import "../utils/SafeMath.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IRewardsDistributor.sol";

contract RewardsDistributor is Ownable, IRewardsDistributor {
    using SafeMath for uint256;

    address private _rewardTokenAddress;
    IERC20 private _rewardToken;
    Recipient[] private _recipients;

    constructor(address owner_, address rewardTokenAddress_) Ownable(owner_) {
        _rewardTokenAddress = rewardTokenAddress_;
        _rewardToken = IERC20(rewardTokenAddress_);
    }

    event RewardRecipientAdded(uint256 index, address recipient, uint256 amount);
    event RewardsDistributed(uint256 amount);

    function getRewardToken() public view returns(address) {
        return _rewardTokenAddress;
    }

    function getRecipient(uint256 _index) external view override returns (address recipient, uint256 amount) {
        recipient = _recipients[_index].recipient;
        amount = _recipients[_index].amount;
    }

    function getRecipientsLength() external view override returns (uint256) {
        return _recipients.length; 
    }

    function setRewardToken(address rewardTokenAddress_) external onlyOwner {
        _rewardTokenAddress = rewardTokenAddress_;
        _rewardToken = IERC20(rewardTokenAddress_);
    } 

    function addRewardRecipient(address _recipient, uint256 _amount) external onlyOwner returns (bool) {
        require(_recipient != address(0), "RewardsDistributor::addRewardRecipient: Cannot add zero address as recipient");
        require(_amount != 0, "RewardsDistributor::addRewardRecipient: Cannot add zero amount");

        Recipient memory r = Recipient(_recipient, _amount);
        _recipients.push(r);

        emit RewardRecipientAdded(_recipients.length - 1, _recipient, _amount);
        return true;
    }

    function removeRewardRecipient(uint256 _index) external onlyOwner {
        require(_index <= _recipients.length - 1, "RewardsDistributor::removeRewardRecipient: Index out of bounds");

        if (_index == _recipients.length - 1) {
            _recipients.pop();
        } else {
            for (uint256 i = _index; i < _recipients.length - 1; i++) {
                _recipients[i] = _recipients[i + 1];
            }
            _recipients.pop();
        }

        // Since this function must shift all later entries down to fill the
        // gap from the one it removed, it could in principle consume an
        // unbounded amount of gas. However, the number of entries will
        // presumably always be very low.
    }

    function editRewardDistribution(
        uint256 _index,
        address _recipient,
        uint256 _amount
    ) 
        external 
        onlyOwner 
        returns (bool) 
    {
        require(_index <= _recipients.length - 1, "RewardsDistributor::editRewardsDistribution: Index out of bounds");
        require(_recipient != address(0), "RewardsDistributor::editRewardsDistribution: Cannot set zero address as recipient");
        require(_amount != 0, "RewardsDistributor::editRewardsDistribution: Cannot set zero amount");

        _recipients[_index].recipient = _recipient;
        _recipients[_index].amount = _amount;

        return true;
    }

    function distributeRewards(uint256 _amount) external override onlyOwner returns (bool) {
        require(_amount > 0, 
            "RewardsDistributor::distributeRewards: Nothing to distribute"
        );
        require(_rewardTokenAddress != address(0),
            "RewardsDistributor::distributeRewards: Cannot send from 0 address"
        );
        require(_rewardToken.balanceOf(address(this)) >= _amount,
            "RewardsDistributor::distributeRewards: Contract does not have enough tokens to distribute"
        );

        uint remainder = _amount;

        // Iterate the array of distributions sending the configured amounts
        for (uint i = 0; i < _recipients.length; i++) {
            if (_recipients[i].recipient != address(0) || _recipients[i].amount != 0) {
                remainder = remainder.sub(_recipients[i].amount);

                // Transfer the SNX
                _rewardToken.transfer(_recipients[i].recipient, _recipients[i].amount);

                // If the contract implements RewardsDistributionRecipient.sol, inform it how many SNX its received.
                bytes memory payload = abi.encodeWithSignature("notifyRewardAmount(uint256)", _recipients[i].amount);

                // solhint-disable avoid-low-level-calls
                (bool success, ) = _recipients[i].recipient.call(payload);

                if (!success) {
                    // Note: we're ignoring the return value as it will fail for contracts that do not implement RewardsDistributionRecipient.sol
                }
            }
        }

        emit RewardsDistributed(_amount);
        return true;
    }

    function claimTokens(address _tokenAddress, uint256 _amount) public onlyOwner {
        if(!IERC20(_tokenAddress).transfer(owner(), _amount)) {
            revert("RewardsDistributor::claimTokens: Claiming tokens has failed");
        }
    }
}