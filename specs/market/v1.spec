/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/v1.sh
	Assumptions: 
*/

using DummyERC20A as token
using ZestyNFT as nft

methods {
	getDepositor(uint256) returns (address) envfree

	// harness
    getAuctionPricePending(uint256) returns uint256 envfree
    getAuctionBuyerCampaign(uint256) returns uint256 envfree
	getAuctionPriceStart(uint256) returns uint256 envfree
	getAuctionPriceEnd(uint256) returns uint256 envfree
	getAuctionCampaignApproved(uint256) returns uint8 envfree
	getAuctionAutoApproveSetting(uint256) returns uint256 envfree
	getSellerByTokenId(uint256) returns address envfree
	getInProgress(uint256) returns uint256 envfree

	dummy() envfree

	// token
	token.balanceOf(address) returns uint256 envfree

	// nft
	nft.ownerOf(uint256) returns address envfree

	// summarize
	getSellerAuctionPrice(uint256 id) => auctionPrice(id)

	// dispatcher
	onERC721Received(address,address,uint256,bytes) => DISPATCHER(true)
}

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////

ghost uint8oracle() returns uint8;
ghost uint256oracle() returns uint256;

/////// campaign id to buyer address ghost
ghost campaignToBuyer(uint256) returns address;

hook Sload address buyer _buyerCampaigns[KEY uint256 id].(offset 0) STORAGE {
	require campaignToBuyer(id) == buyer;
}

hook Sstore _buyerCampaigns[KEY uint256 id].(offset 0) address buyer STORAGE {
	havoc campaignToBuyer assuming campaignToBuyer@new(id) == buyer &&
		(forall uint256 id2. id != id2 => campaignToBuyer@new(id2) == campaignToBuyer@old(id2));
}

/////// auction price ghost - completely uninterpreted
ghost auctionPrice(uint256) returns uint256;

/////// auction price start ghost
ghost auctionPriceStart(uint256) returns uint256;

hook Sload uint value _sellerAuctions[KEY uint256 id].(offset 64) STORAGE {
	require auctionPriceStart(id) == value;
}

hook Sstore _sellerAuctions[KEY uint256 id].(offset 64) uint value STORAGE {
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


////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: title  
 	Description:  
	Formula: 
	Notes: assumptions and simplification more explanations 
*/

// status: rerun - fails in bidbatch - there's a price end and it just sets it. need to check buyerCampaignApproved too (which is autoset by autoApprove)
invariant oncePriceEndWasSetPricePendingMustBeZeroAndMustBeApproved(uint256 auctionId) getAuctionPriceEnd(auctionId) != 0 => getAuctionPricePending(auctionId) == 0 && getAuctionCampaignApproved(auctionId) == 2

// status: failing because pending and campaign could be nullified but priceEnd was set to something before, should be impossible
invariant auctionHasPricePendingOrEndIfAndOnlyIfHasBuyerCampaign(uint256 auctionId)
    (getAuctionPricePending(auctionId) != 0 || getAuctionPriceEnd(auctionId) != 0) <=> getAuctionBuyerCampaign(auctionId) != 0 {
		preserved {
			requireInvariant buyerCampaignCountIsGtZero();
			requireInvariant oncePriceEndWasSetPricePendingMustBeZero(auctionId);
			requireInvariant aboveBuyerCampaignCountBuyerIsZero();
		}
	}

// status: fails in withdraw because of NFT index collision
invariant depositedNFTsBelongToMarket(uint256 tokenId) getSellerByTokenId(tokenId) != 0 => nft.ownerOf(tokenId) == currentContract

// status: passed, including sanity
invariant aboveSellerAuctionCountSellerIsZero(uint256 auctionId) auctionId >= sellerAuctionCount() => auctionSeller(auctionId) == 0

// status: running
invariant aboveBuyerCampaignCountBuyerIsZero(uint256 campaignId) (campaignId >= buyerCampaignCount() => campaignToBuyer(campaignId) == 0) && campaignToBuyer(0) == 0 {
	preserved {
		requireInvariant buyerCampaignCountIsGtZero();
	}
}

// status: passing, check sanity
invariant nftDepositorIsSameAsSellerInNFTSettings(uint256 tokenId) getSellerByTokenId(tokenId) == getDepositor(tokenId)

// if our auction is for a token ID, that token ID must map to the same seller, and in progress count should be greater than 0
// the other direction may not be correct since a seller may auction numerous tokens, and the same token for numerous time slots
// status: passing, check sanity
invariant sellerNFTSettingsMatchSellerAuction(uint256 tokenId, uint256 auctionId) 
	auctionSeller(auctionId) != 0 && auctionToTokenId(auctionId) == tokenId =>
		getSellerByTokenId(tokenId) == auctionSeller(auctionId) {
	preserved {
		requireInvariant depositedNFTsBelongToMarket(tokenId);
		requireInvariant aboveSellerAuctionCountSellerIsZero(auctionId);
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

// status: has failures, check them	
invariant autoApproveValid(uint256 tokenId) getSellerByTokenId(tokenId) != 0 <=> (getAuctionAutoApproveSetting(tokenId) == 1 || getAuctionAutoApproveSetting(tokenId) == 2)

// status: failing when removing an auction
invariant autoApproveValidIffSellerNonZero(uint256 auctionId) auctionSeller(auctionId) != 0 <=> (getAuctionAutoApproveSetting(auctionToTokenId(auctionId)) == 1 || getAuctionAutoApproveSetting(auctionToTokenId(auctionId)) == 2) {
	preserved {
		requireInvariant sellerNFTSettingsMatchSellerAuction(auctionToTokenId(auctionId), auctionId);
		requireInvariant aboveSellerAuctionCountSellerIsZero(auctionId);
		requireInvariant depositedNFTsBelongToMarket(auctionToTokenId(auctionId));
	}
}

rule ifThereIsASellerAutoApproveMustBeOneOrTwo(uint256 auctionId, uint256 tokedId) {
	env e;
	address seller;

	seller, _, _, _, _, _, _, _, _, _, _ = getSellerAuction(e, auctionId);
	assert seller != 0 <=> getAuctionAutoApproveSetting(tokedId) != 0;
}

function validStateAuction(uint auctionId) {
	require auctionPriceStart(auctionId) >= auctionPrice(auctionId); // TODO: Check in priceShouldAlwaysBeBetweenPriceStartAndPriceEnd
} 

function validStateBuyer(uint campaignId) {
	// use invaraint aboveBuyerCampaignCountBuyerIsZero
	require campaignId == 0 => campaignToBuyer(campaignId) == 0; // TODO and strengthen (to an iff)
}

////////////////////////////////////////////////////////////////////////////
//                       Rules                                            //
////////////////////////////////////////////////////////////////////////////
    
rule auctionAutoApprovalCanBeTrueOrFalse(uint256 _tokenId) {

	env e;

	uint8 _autoApproveTrue = 2;
	uint8 _autoApproveFalse = 1;
	uint8 _autoApproveOther = 0;

	require _tokenId > 0;
	require e.msg.value == 0;

	sellerNFTDeposit(e, _tokenId, _autoApproveTrue);
	assert true;

	sellerNFTDeposit(e, _tokenId, _autoApproveFalse);
	assert true;

	sellerNFTDeposit(e, _tokenId, _autoApproveOther);
	assert false;
}

rule auctionAutoApprovalCanBeTrueOrFalseA(uint256 _tokenId) {

	env e;

	uint8 _autoApproveTrue = 2;
	uint8 _autoApproveFalse = 1;
	uint8 _autoApproveOther = 0;

	require _tokenId > 0;
	require e.msg.value == 0;

	sellerNFTDeposit@withrevert(e, _tokenId, _autoApproveTrue);
	assert !lastReverted;

	sellerNFTDeposit@withrevert(e, _tokenId, _autoApproveFalse);
	assert !lastReverted;

	sellerNFTDeposit@withrevert(e, _tokenId, _autoApproveOther);
	assert lastReverted;
}

rule priceShouldAlwaysBeBetweenPriceStartAndPriceEnd {
	env e;
	calldataarg args;

	uint256 _sellerAuctionId;
	uint256 _auctionPriceStart;
	uint256 _auctionPriceEnd;
	uint256 _auctionPrice;

	sellerNFTDeposit(e, args);
	sellerAuctionCreateBatch(e, args);
	buyerCampaignCreate(e, args);
	sellerAuctionBidBatch(e, args);

	_auctionPriceStart = getAuctionPriceStart(args);
	_auctionPriceEnd = getAuctionPriceEnd(args);
	_auctionPrice = getSellerAuctionPrice(e, args);

	assert (_auctionPriceStart >= _auctionPrice) && (_auctionPrice >= _auctionPriceEnd);
}


// Status: sanity issue
rule bidAdditivity(uint x, uint y, address who) {
	validStateAuction(x);
	validStateAuction(y);
	uint256 campaignId = uint256oracle();
	validStateBuyer(campaignId);
	additivity(x, y, who, sellerAuctionBidBatch(uint256[],uint256).selector);
	assert true;
}

// Status: passing including sanity
rule buyerCampaignCountMonotonicallyIncreasing(method f) {
	uint pre = buyerCampaignCount();

	env e;
	calldataarg arg;
	f(e, arg);

	uint post = buyerCampaignCount();

	assert post >= pre;
	assert post > pre => f.selector == buyerCampaignCreate(string).selector;
	assert pre != 0 => post != 0;
}

invariant buyerCampaignCountIsGtZero() buyerCampaignCount() > 0

rule sellerAuctionCountMonotonicallyIncreasing(method f) {
	uint pre = sellerAuctionCount();

	env e;
	calldataarg arg;
	f(e, arg);

	uint post = sellerAuctionCount();

	assert post >= pre;
	assert post > pre => f.selector == sellerAuctionCreateBatch(uint256,uint256[],uint256[],uint256[],uint256[],uint256[]).selector;
	assert pre != 0 => post != 0;
}

invariant sellerAuctionCountIsGtZero() sellerAuctionCount() > 0

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

function additivity(uint x, uint y, address who, uint32 funcId) {
	storage init = lastStorage;

	callFunctionWithAmountAndSender(funcId, [x], who);
	callFunctionWithAmountAndSender(funcId, [y], who);

	uint splitWho = token.balanceOf(who);
	uint splitMarket = token.balanceOf(currentContract);

	dummy() at init; // reset the storage
	callFunctionWithAmountAndSender(funcId, [x,y], who);

	uint unifiedWho = token.balanceOf(who);
	uint unifiedMarket = token.balanceOf(currentContract);

	assert splitWho == unifiedWho, "operation is not additive for the given address balance";
	assert splitMarket == unifiedMarket, "operation is not additive for the market balance";
}

function callFunctionWithAmountAndSender(uint32 funcId, uint[] array, address who) {
	if (funcId == sellerAuctionBidBatch(uint256[],uint256).selector) {
		env e;
		require e.msg.sender == who;
		uint campaignId; // = uint256oracle();
		validStateBuyer(campaignId);
		sellerAuctionBidBatch(e, array, campaignId);
	} else {
		require false;
	}
}