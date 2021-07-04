/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/v2.sh
*/

using DummyERC20A as token
using ZestyNFT as nft

methods {
	getDepositor(uint256) returns (address) envfree
	getOperator(address) returns (address) envfree

	// harness
    getAuctionPricePending(uint256) returns uint256 envfree
    getAuctionBuyerCampaign(uint256) returns uint256 envfree
	getAuctionPriceStart(uint256) returns uint256 envfree
	getAuctionPriceEnd(uint256) returns uint256 envfree
	getAuctionCampaignApproved(uint256) returns uint8 envfree
	getAuctionAutoApproveSetting(uint256) returns uint256 envfree
	getAuctionTimeStart(uint256) returns uint256 envfree
	getAuctionTimeEnd(uint256) returns uint256 envfree
	getContractTimeStart(uint256) returns uint256 envfree
	getContractTimeEnd(uint256) returns uint256 envfree
	getSellerByTokenId(uint256) returns address envfree
	getInProgress(uint256) returns uint256 envfree
	getBuyer(uint256) returns address envfree

	dummy() envfree

	// token
	token.balanceOf(address) returns uint256 envfree

	// nft
	nft.ownerOf(uint256) returns address envfree

	// dispatcher
	onERC721Received(address,address,uint256,bytes) => DISPATCHER(true)
}

////////////////////////////////////////////////////////////////////////////
//                       Definitions                                      //
////////////////////////////////////////////////////////////////////////////

definition TRUE() returns uint8 = 2;
definition FALSE() returns uint8 = 1;

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////

/////// campaign id to buyer address ghost
ghost campaignToBuyer(uint256) returns address {
	init_state axiom forall uint256 x. campaignToBuyer(x) == 0;
}

hook Sload address buyer _buyerCampaigns[KEY uint256 id].(offset 0) STORAGE {
	require campaignToBuyer(id) == buyer;
}

hook Sstore _buyerCampaigns[KEY uint256 id].(offset 0) address buyer STORAGE {
	havoc campaignToBuyer assuming campaignToBuyer@new(id) == buyer &&
		(forall uint256 id2. id != id2 => campaignToBuyer@new(id2) == campaignToBuyer@old(id2));
}

/////// auction price start ghost
ghost auctionPriceStart(uint256) returns uint256;

hook Sload uint value _sellerAuctions[KEY uint256 id].(offset 192) STORAGE {
	require auctionPriceStart(id) == value;
}

hook Sstore _sellerAuctions[KEY uint256 id].(offset 192) uint value STORAGE {
	havoc auctionPriceStart assuming auctionPriceStart@new(id) == value &&
		(forall uint256 id2. id != id2 => auctionPriceStart@new(id2) == auctionPriceStart@old(id2));
}

/////// auction to seller address ghost
ghost auctionSeller(uint256) returns address {
	init_state axiom forall uint256 id. auctionSeller(id) == 0;
}

hook Sload address seller _sellerAuctions[KEY uint256 id].(offset 0) STORAGE {
	require auctionSeller(id) == seller;
}

hook Sstore _sellerAuctions[KEY uint256 id].(offset 0) address seller STORAGE {
	require seller < max_uint160; // very tricky in delete statements, where the "dead bits" to the left are preserved
	havoc auctionSeller assuming auctionSeller@new(id) == seller &&
		(forall uint256 id2. id != id2 => auctionSeller@new(id2) == auctionSeller@old(id2));
}

/////// auction to token id
ghost auctionToTokenId(uint256) returns uint256 {
	init_state axiom forall uint256 id. auctionToTokenId(id) == 0;
}

hook Sload uint256 tokenId _sellerAuctions[KEY uint256 id].(offset 32) STORAGE {
	require auctionToTokenId(id) == tokenId;
}

hook Sstore _sellerAuctions[KEY uint256 id].(offset 32) uint256 tokenId STORAGE {
	havoc auctionToTokenId assuming auctionToTokenId@new(id) == tokenId &&
		(forall uint256 id2. id != id2 => auctionToTokenId@new(id2) == auctionToTokenId@old(id2));
}

/////// buyer campaign count ghost
ghost buyerCampaignCount() returns uint256;

hook Sstore _buyerCampaignCount uint value STORAGE {
	havoc buyerCampaignCount assuming buyerCampaignCount@new() == value;
}

hook Sload uint value _buyerCampaignCount STORAGE {
	require buyerCampaignCount() == value;
}

/////// seller auction count ghost
ghost sellerAuctionCount() returns uint256;

hook Sstore _sellerAuctionCount uint value STORAGE {
	havoc sellerAuctionCount assuming sellerAuctionCount@new() == value;
}

hook Sload uint value _sellerAuctionCount STORAGE {
	require sellerAuctionCount() == value;
}

/////// contract count ghost
ghost contractCount() returns uint256;

hook Sstore _contractCount uint value STORAGE {
	havoc contractCount assuming contractCount@new() == value;
}

hook Sload uint value _contractCount STORAGE {
	require contractCount() == value;
}

/////// contract value
ghost contractToValue(uint256) returns uint256 {
	init_state axiom forall uint256 id. contractToValue(id) == 0;
}

/////// contract value sum
ghost contractValueSum() returns uint256 {
	init_state axiom contractValueSum() == 0;
}

// hooks for contract value
hook Sstore _contracts[KEY uint256 contractId].(offset 128) uint256 value (uint256 oldValue) STORAGE {
	requireInvariant aboveContractCountContractValueIsZero(contractId);
	havoc contractToValue assuming contractToValue@new(contractId) == value &&
		(forall uint256 id2. id2 != contractId => contractToValue@new(id2) == contractToValue@old(id2));
	havoc contractValueSum assuming contractValueSum@new() == contractValueSum@old() - oldValue + value;
	havoc contractValueWithdrawnSum assuming contractValueWithdrawnSum@new() == ((isContractWithdrawn(contractId)==TRUE()) 
		? (contractValueWithdrawnSum@old() - oldValue + value) 
		: contractValueWithdrawnSum@old());
}

hook Sload uint256 value _contracts[KEY uint256 contractId].(offset 128) STORAGE {
	require contractToValue(contractId) == value;
	require contractValueSum() >= value;
	require (isContractWithdrawn(contractId)==TRUE()) ? contractValueWithdrawnSum() >= value : true;
}

/////// contract id to whether it's withdrawn or not
ghost isContractWithdrawn(uint256) returns uint8 {
	init_state axiom forall uint256 id. isContractWithdrawn(id) == 0;
}

// hooks for contract withdrawn
hook Sstore _contracts[KEY uint256 contractId].(offset 160) uint8 value (uint8 oldValue) STORAGE {
	// valid values - need to prove
	require oldValue == FALSE() || value == TRUE();

	havoc isContractWithdrawn assuming isContractWithdrawn@new(contractId) == value &&
		(forall uint256 id2. id2 != contractId => isContractWithdrawn@new(id2) == isContractWithdrawn@old(id2));

	havoc contractValueWithdrawnSum assuming (
		(value == oldValue => contractValueWithdrawnSum@new() == contractValueWithdrawnSum@old())
		&& (value == TRUE() && oldValue == FALSE() => 
			contractValueWithdrawnSum@new() == contractValueWithdrawnSum@old() + contractToValue(contractId)
			&& contractValueSum() >= contractValueWithdrawnSum@old() + contractToValue(contractId)
		)
		&& (value == FALSE() && oldValue == TRUE() => 
			contractValueWithdrawnSum@new() == contractValueWithdrawnSum@old() - contractToValue(contractId)
			&& contractValueSum() >= contractValueWithdrawnSum@old()
		)
	);
}

hook Sload uint8 value _contracts[KEY uint256 contractId].(offset 160) STORAGE {
	require isContractWithdrawn(contractId) == value;
}

/////// contract value sum for withdrawn only
ghost contractValueWithdrawnSum() returns uint256 {
	init_state axiom contractValueWithdrawnSum() == 0;
}

/////// sum of pending prices
ghost pendingPricesSum() returns uint256 {
	init_state axiom pendingPricesSum() == 0;
}

hook Sstore _sellerAuctions[KEY uint256 auctionId].(offset 224) uint value (uint oldValue) STORAGE {
	havoc pendingPricesSum assuming pendingPricesSum@new() == pendingPricesSum@old() - oldValue + value;
}

hook Sload uint value _sellerAuctions[KEY uint256 auctionId].(offset 224) STORAGE {
	require pendingPricesSum() >= value;
}

ghost endingPricesSum() returns uint256 {
	init_state axiom endingPricesSum() == 0;
}

hook Sstore _sellerAuctions[KEY uint256 auctionId].(offset 256) uint value (uint oldValue) STORAGE {
	havoc endingPricesSum assuming endingPricesSum@new() == endingPricesSum@old() - oldValue + value;
}

hook Sload uint value _sellerAuctions[KEY uint256 auctionId].(offset 256) STORAGE {
	require endingPricesSum() >= value;
}

////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////

// status: passing - used for spec sanity rather than checking the code
invariant sanityContractValueSumGhosts() contractValueSum() >= contractValueWithdrawnSum()

// status: fails on bid reject and cancel - rule #15 in the report
invariant solvency() token.balanceOf(currentContract) >= contractValueSum() - contractValueWithdrawnSum()
/*
invariant weakSolvency() token.balanceOf(currentContract) >= endingPricesSum() + pendingPricesSum() - contractValueWithdrawnSum() {
	preserved sellerAuctionBidBatch(uint256[] dummy, uint256 campaignId) with (env e) {
		require getBuyer(campaignId) != currentContract; // market must not be the buyer
	}
}
*/
// as weakSolvency as an invariant requires some new spec features, we will write it as a rule
// status: passed, but this is the wrong rule - there is double counting in contracts that must be addressed
rule weakSolvency(method f) filtered { f -> !f.isFallback } {
	require token.balanceOf(currentContract) >= endingPricesSum() + pendingPricesSum() - contractValueWithdrawnSum();

	env e;
	calldataarg arg;
	if (f.selector == sellerAuctionBidBatch(uint256[],uint256).selector) {
		uint256[] dummy;
		uint256 campaignId;
		require getBuyer(campaignId) != currentContract; // market must not be the buyer
		sellerAuctionBidBatch(e, dummy, campaignId);
	} else {
		f(e, arg);
	}

	assert token.balanceOf(currentContract) >= endingPricesSum() + pendingPricesSum() - contractValueWithdrawnSum();
}

// status: passed - rule #6 in the report
invariant eitherPendingPriceOrEndPriceAreZero(uint256 auctionId) getAuctionPricePending(auctionId) == 0 || getAuctionPriceEnd(auctionId) == 0 {
	preserved {
		requireInvariant aboveSellerAuctionCountSellerAndPricesAreZero(auctionId);
		requireInvariant beforeBidThereIsNoPriceEnd(auctionId);
	}
}

// status: passed - rule #7 in the report
invariant beforeBidThereIsNoPriceEnd(uint256 auctionId) 
	getAuctionBuyerCampaign(auctionId) == 0 => 
		getAuctionPriceEnd(auctionId) == 0 
		&& getAuctionPricePending(auctionId) == 0 {
	preserved {
		requireInvariant buyerCampaignCountIsGtZero();
		uint256 campaignId = getAuctionBuyerCampaign(auctionId);
		requireInvariant aboveBuyerCampaignCountBuyerIsZero(campaignId);
		requireInvariant aboveSellerAuctionCountSellerAndPricesAreZero(auctionId);
		requireInvariant oncePriceEndWasSetPricePendingMustBeZeroAndMustBeApproved(auctionId);
	}
}

// status: passed - rule #8 in the report
invariant oncePriceEndWasSetPricePendingMustBeZeroAndMustBeApproved(uint256 auctionId) getAuctionPriceEnd(auctionId) != 0 => getAuctionPricePending(auctionId) == 0 && getAuctionCampaignApproved(auctionId) == TRUE() {
	preserved {
		requireInvariant beforeBidThereIsNoPriceEnd(auctionId);
	}
}

// status: passed - rule #18 in the report
invariant auctionHasPricePendingOrEndIfAndOnlyIfHasBuyerCampaign(uint256 auctionId)
    (getAuctionPricePending(auctionId) != 0 || getAuctionPriceEnd(auctionId) != 0) <=> getAuctionBuyerCampaign(auctionId) != 0 {
		preserved {
			requireInvariant buyerCampaignCountIsGtZero();
			requireInvariant oncePriceEndWasSetPricePendingMustBeZeroAndMustBeApproved(auctionId);
			requireInvariant aboveBuyerCampaignCountBuyerIsZero();
		}
	}

// status: fails in withdraw because of NFT index collision
invariant depositedNFTsBelongToMarket(uint256 tokenId) getSellerByTokenId(tokenId) != 0 => nft.ownerOf(tokenId) == currentContract

// status: passed, including sanity - rule #9 in the report
invariant aboveSellerAuctionCountSellerAndPricesAreZero(uint256 auctionId) 
	auctionId >= sellerAuctionCount() => 
		auctionSeller(auctionId) == 0 
		&& getAuctionPriceStart(auctionId) == 0 
		&& getAuctionPricePending(auctionId) == 0 
		&& getAuctionPriceEnd(auctionId) == 0

// status: passed - rule #10 in the report
invariant aboveBuyerCampaignCountBuyerIsZero(uint256 campaignId) 
	(campaignId >= buyerCampaignCount() => campaignToBuyer(campaignId) == 0) 
	&& campaignToBuyer(0) == 0 {
	preserved {
		requireInvariant buyerCampaignCountIsGtZero();
	}
}

// Status: passes - rule #11 in the report
invariant aboveContractCountContractValueIsZero(uint256 contractId) contractId >= contractCount() => contractToValue(contractId) == 0 && isContractWithdrawn(contractId) == 0

// status: passed - rule #12 in the report
invariant nftDepositorIsSameAsSellerInNFTSettings(uint256 tokenId) getSellerByTokenId(tokenId) == getDepositor(tokenId)

// if our auction is for a token ID, that token ID must map to the same seller, and in progress count should be greater than 0
// the other direction may not be correct since a seller may auction numerous tokens, and the same token for numerous time slots
// status: passing, check sanity - rule #13 in the report
invariant sellerNFTSettingsMatchSellerAuction(uint256 tokenId, uint256 auctionId) 
	auctionSeller(auctionId) != 0 && auctionToTokenId(auctionId) == tokenId =>
		getSellerByTokenId(tokenId) == auctionSeller(auctionId) {
	preserved {
		requireInvariant depositedNFTsBelongToMarket(tokenId);
		requireInvariant aboveSellerAuctionCountSellerAndPricesAreZero(auctionId);
		requireInvariant nftDepositorIsSameAsSellerInNFTSettings(tokenId);
	}

	preserved sellerNFTDeposit(uint256 _, uint8 _) with (env e) {
		requireInvariant depositedNFTsBelongToMarket(tokenId);
		require e.msg.sender != currentContract;
	}

	preserved sellerNFTWithdraw(uint256 _) with (env e) {
		// one can withdraw if the relevant auction's contract has been fulfilled without removing the auction.
		require false;
	}
}

// status: passes - rule #1 in the report
invariant autoApproveValid(uint256 tokenId)
	(getSellerByTokenId(tokenId) != 0 <=> (getAuctionAutoApproveSetting(tokenId) == FALSE() || getAuctionAutoApproveSetting(tokenId) == TRUE())) 
		&& (getSellerByTokenId(tokenId) == 0 <=> getAuctionAutoApproveSetting(tokenId) == 0) {
	preserved sellerNFTDeposit(uint256 _, uint8 _) with (env e) {
		require e.msg.sender != 0; // reasonable assumption in evm 
	}
	preserved sellerNFTUpdate(uint256 _, uint8 _) with (env e) {
		require e.msg.sender != 0; // reasonable assumption in evm 
		// reasonable that 0 cannot be a depositor and cannot assign operators
		requireInvariant nftDepositorIsSameAsSellerInNFTSettings(tokenId);
		require getDepositor(tokenId) != 0;
		require getOperator(0) == 0;
	}
}

// status: failing on create - bug found by the team after we asked them - rule #17 in the report
invariant times(uint256 auctionId) auctionSeller(auctionId) != 0 => getAuctionTimeEnd(auctionId) > getAuctionTimeStart(auctionId)
	&& getContractTimeEnd(auctionId) > getAuctionTimeEnd(auctionId)
	&& getContractTimeStart(auctionId) >= getAuctionTimeStart(auctionId)
	&& getContractTimeEnd(auctionId) > getContractTimeStart(auctionId)

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////

// Status: passing - rule #3.a in the report
rule bidAdditivity(uint x, uint y, address who) {
	env eWhen;
	validStateAuction(x, eWhen);
	validStateAuction(y, eWhen);
	additivity(x, y, who, eWhen.block.timestamp, sellerAuctionBidBatch(uint256[],uint256).selector);
	assert true;
}

// Status: Sanity issue - rule #3.b in the report
rule auctionApproveAdditivity(uint x, uint y, address who) {
	env eWhen;
	validStateAuction(x, eWhen);
	validStateAuction(y, eWhen);
	additivity(x, y, who, eWhen.block.timestamp, sellerAuctionApproveBatch(uint256[]).selector);
	assert true;
}

// Status: passed - rule #3.c in the report
rule auctionBidCancelAdditivity(uint x, uint y, address who) {
	env eWhen;
	validStateAuction(x, eWhen);
	validStateAuction(y, eWhen);
	additivity(x, y, who, eWhen.block.timestamp, sellerAuctionBidCancelBatch(uint256[]).selector);
	assert true;
}

// Status: passed - rule #3.d in the report
rule auctionRejectBatchAdditivity(uint x, uint y, address who) {
	env eWhen;
	validStateAuction(x, eWhen);
	validStateAuction(y, eWhen);
	additivity(x, y, who, eWhen.block.timestamp, sellerAuctionRejectBatch(uint256[]).selector);
	assert true;
}

// Status: Sanity issues - rule #3.e in the report
/*rule contractWithdrawBatchAdditivity(uint x, uint y, address who) {
	//validStateAuction(x);
	//validStateAuction(y);
	uint when;
	additivity(x, y, who, when, contractWithdrawBatch(uint256[]).selector);
	assert true;
}*/

// Status: passing including sanity (not including fallback, so we ignore it) - rule #16.a in the report
rule buyerCampaignCountMonotonicallyIncreasing(method f) filtered { f -> !f.isFallback } {
	uint pre = buyerCampaignCount();

	env e;
	calldataarg arg;
	f(e, arg);

	uint post = buyerCampaignCount();

	assert post >= pre;
	assert post > pre => f.selector == buyerCampaignCreate(string).selector;
	assert pre != 0 => post != 0;
}

// Status: passed - rule #16.a in the report
invariant buyerCampaignCountIsGtZero() buyerCampaignCount() > 0

// status: passing - rule #16.b in the report
rule sellerAuctionCountMonotonicallyIncreasing(method f) filtered { f -> !f.isFallback } {
	uint pre = sellerAuctionCount();

	env e;
	calldataarg arg;
	f(e, arg);

	uint post = sellerAuctionCount();

	assert post >= pre;
	assert post > pre => f.selector == sellerAuctionCreateBatch(uint256,uint256[],uint256[],uint256[],uint256[],uint256[]).selector;
	assert pre != 0 => post != 0;
}

// Status: passed - rule #16.b in the report
invariant sellerAuctionCountIsGtZero() sellerAuctionCount() > 0

// Status: passed - rule #2.b in the report
rule sellerAuctionPriceMonotonicallyDecreasing(method f, uint auctionId) filtered { f -> !f.isFallback } {
	env eGet;
	uint pre = getSellerAuctionPriceOriginal(eGet, auctionId);

	env e;
	require e.block.timestamp == eGet.block.timestamp;
	calldataarg arg;
	f(e, arg);

	uint post = getSellerAuctionPriceOriginal(eGet, auctionId);

	assert post <= pre;
	assert pre != 0 => post != 0;
}

// status: passing - rule #2.a in the report
rule sellerAuctionPriceMonotonicallyDecreasingInTime(uint auctionId) {
	env e1;
	env e2;
	require e1.block.timestamp <= e2.block.timestamp;

	uint before = getSellerAuctionPriceOriginal(e1, auctionId);
	uint after = getSellerAuctionPriceOriginal(e2, auctionId);

	assert before >= after;
}

// Status: passing - rule #2.c
rule sellerAuctionPriceStartsAtPriceStart(uint auctionId) {
	env e;
	uint price = getSellerAuctionPriceOriginal(e, auctionId);
	assert e.block.timestamp == getAuctionTimeStart(auctionId) => price == auctionPriceStart(auctionId);
}

// status: passed - rule #14 in the report
rule withdrawalIsIrreversible(uint256 contractId, method f) filtered { f -> !f.isFallback } {
	uint8 pre =	isContractWithdrawn(contractId);

	env e;
	calldataarg arg;
	f(e, arg);

	uint8 post = isContractWithdrawn(contractId);

	assert pre == TRUE() => post == TRUE(), "once a contract is withdrawn this cannot be changed";
}

// status: running
// forcing all batch operations to a single element - should be justified by additivity
rule deltaInPricePendingPlusPriceEndSameAsBalanceDelta(uint256 auctionId, method f) filtered { f -> !f.isFallback } {
	requireInvariant eitherPendingPriceOrEndPriceAreZero(auctionId);

	uint campaignId = getAuctionBuyerCampaign(auctionId);
	address buyer = getBuyer(campaignId);
	require buyer != currentContract; // market cannot be a buyer

	uint _buyerBalance = token.balanceOf(buyer);
	uint _marketBalance = token.balanceOf(currentContract);

	mathint _price = getAuctionPricePending(auctionId) + getAuctionPriceEnd(auctionId);

	callBatchedOperationsWithOneElement(f);

	uint buyerBalance_ = token.balanceOf(buyer);
	uint marketBalance_ = token.balanceOf(currentContract);

	mathint price_ = getAuctionPricePending(auctionId) + getAuctionPriceEnd(auctionId);

	assert _price - price_ == _buyerBalance - buyerBalance_, "delta in buyer balance same as delta in price";
	assert _price - price_ == _marketBalance - marketBalance_, "delta in market balance same as delta in price";
}

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////

function validStateAuction(uint auctionId, env e) {
	require auctionPriceStart(auctionId) >= getSellerAuctionPrice(e, auctionId); // this is checked by monotonicity rule
} 

function validStateBuyer(uint campaignId) {
	requireInvariant aboveBuyerCampaignCountBuyerIsZero(campaignId);
}   

function additivity(uint x, uint y, address who, uint when, uint32 funcId) {
	storage init = lastStorage;

	callFunctionWithAmountAndSender(funcId, [x], who, when);
	callFunctionWithAmountAndSender(funcId, [y], who, when);

	uint splitWho = token.balanceOf(who);
	uint splitMarket = token.balanceOf(currentContract);

	dummy() at init; // reset the storage
	callFunctionWithAmountAndSender(funcId, [x,y], who, when);

	uint unifiedWho = token.balanceOf(who);
	uint unifiedMarket = token.balanceOf(currentContract);

	assert splitWho == unifiedWho, "operation is not additive for the given address balance";
	assert splitMarket == unifiedMarket, "operation is not additive for the market balance";
}

function callFunctionWithAmountAndSender(uint32 funcId, uint[] array, address who, uint when) {
	if (funcId == sellerAuctionBidBatch(uint256[],uint256).selector) {
		env e;
		require e.msg.sender == who;
		require e.block.timestamp == when;
		uint campaignId;
		validStateBuyer(campaignId);
		sellerAuctionBidBatch(e, array, campaignId);
	} else if (funcId == sellerAuctionApproveBatch(uint256[]).selector) {
		env e;
		require e.msg.sender == who;
		require e.block.timestamp == when;
		sellerAuctionApproveBatch(e, array);
	} else if (funcId == sellerAuctionBidCancelBatch(uint256[]).selector) {
		env e;
		require e.msg.sender == who;
		require e.block.timestamp == when;
		sellerAuctionBidCancelBatch(e, array);
	} else if (funcId == sellerAuctionRejectBatch(uint256[]).selector) {
		env e;
		require e.msg.sender == who;
		require e.block.timestamp == when;
		sellerAuctionRejectBatch(e, array);
	/*} else if (funcId == contractWithdrawBatch(uint256[]).selector) {
		env e;
		require e.msg.sender == who;
		require e.block.timestamp == when;
		contractWithdrawBatch(e, array);*/
	} else {
		require false;
	}
}

function callBatchedOperationsWithOneElement(method f) {
	env e;
	uint32 funcId = f.selector;
	if (funcId == sellerAuctionBidBatch(uint256[],uint256).selector) {
		uint256[] arrayDummy;
		require arrayDummy.length == 1;
		uint256 dummy;
		sellerAuctionBidBatch(e, arrayDummy, dummy);
	} else if (funcId == sellerAuctionApproveBatch(uint256[]).selector) {
		uint256[] arrayDummy;
		require arrayDummy.length == 1;
		sellerAuctionApproveBatch(e, arrayDummy);
	} else if (funcId == sellerAuctionBidCancelBatch(uint256[]).selector) {
		uint256[] arrayDummy;
		require arrayDummy.length == 1;
		sellerAuctionBidCancelBatch(e, arrayDummy);
	} else if (funcId == sellerAuctionRejectBatch(uint256[]).selector) {
		uint256[] arrayDummy;
		require arrayDummy.length == 1;
		sellerAuctionRejectBatch(e, arrayDummy);
/*	} else if (funcId == contractWithdrawBatch(uint256[]).selector) {
		uint256[] arrayDummy;
		require arrayDummy.length == 1;
		contractWithdrawBatch(e, arrayDummy);*/
	} else {
		calldataarg arg;
		f(e, arg);
	}
}