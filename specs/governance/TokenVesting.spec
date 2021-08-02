/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/tokenVesting.sh
*/

using DummyERC20A as token

methods {
	// harness
	getVaultStartTime(address) returns uint256 envfree
	getVaultAmount(address) returns uint256 envfree
	getVaultAmountClaimed(address) returns uint256 envfree
	getVaultVestingDuration(address) returns uint256 envfree
	getVaultVestingCliff(address) returns uint256 envfree

	dummy() envfree

	token.balanceOf(address) returns uint256 envfree
}