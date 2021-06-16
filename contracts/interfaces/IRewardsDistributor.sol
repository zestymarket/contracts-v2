// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

// Adapted from synthetix IRewardsDistributor

interface IRewardsDistributor {
    struct Recipient {
        address recipient;
        uint256 amount;
    }

    function getRecipient(uint256 index) external view returns (address recipient, uint256 amount);
    function getRecipientsLength() external view returns (uint256);

    function distributeRewards(uint256 amount) external returns (bool);
}