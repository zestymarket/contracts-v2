pragma solidity ^0.7.6;

import "../../contracts/governance/TokenVesting.sol";

contract TokenVestingHarness is TokenVesting {

    constructor(
        address owner_,
        address token_
    ) 
        TokenVesting(owner_, token_);
    {
    }

    function getVaultStartTime(address _recipient) external view returns (uint256) {
        uint256 ret;
        (ret, , , , ) = TokenVesting(this).getVault(_recipient);
        return ret;
    }

    function getVaultAmount(address _recipient) external view returns (uint256) {
        uint256 ret;
        (, ret, , , ) = TokenVesting(this).getVault(_recipient);
        return ret;
    }

    function getVaultAmountClaimed(address _recipient) external view returns (uint256) {
        uint256 ret;
        (, , ret, , ) = TokenVesting(this).getVault(_recipient);
        return ret;
    }

    function getVaultVestingDuration(address _recipient) external view returns (uint256) {
        uint256 ret;
        (, , , ret, ) = TokenVesting(this).getVault(_recipient);
        return ret;
    }

    function getVaultVestingCliff(address _recipient) external view returns (uint256) {
        uint256 ret;
        (, , , , ret) = TokenVesting(this).getVault(_recipient);
        return ret;
    }

    // used for resetting storage in spec
    function dummy() external {}
}