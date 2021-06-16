// SPDX-License-Identifier: MIT

// Adapted from synthetix RewardsDistributionRecipient

pragma solidity ^0.7.6;

import "../utils/Ownable.sol";
import "../utils/Context.sol";

abstract contract RewardsRecipient is Context, Ownable {
    address private _rewardsDistributor;

    constructor(address owner_, address rewardsDistributor_) 
        Ownable(owner_) 
    {
        _rewardsDistributor = rewardsDistributor_;
    } 

    function getRewardsDistributor() public view virtual returns (address) {
        return _rewardsDistributor;
    }

    function notifyRewardAmount(uint256 rewards) external virtual {}

    function setRewardsDistributor(address rewardsDistributor_) external virtual onlyOwner {
        _rewardsDistributor = rewardsDistributor_;
    }

    modifier onlyRewardsDistributor() {
        require(
            _msgSender() == _rewardsDistributor, 
            "RewardsRecipient::onlyRewardsDistributor: Caller is not RewardsDistributor"
        );
        _;
    }
}

