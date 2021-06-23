/*
    This is a specification file for smart contract verification with the Certora prover.
    For more information, visit: https://www.certora.com/

    This file is run with scripts/v1.sh
	Assumptions: 
*/

using DummyERC20A as token

methods {
    getAuctionPricePending(uint256) returns uint256 envfree
    getAuctionBuyerCampaign(uint256) returns uint256 envfree
	getAuctionPriceStart(uint256) returns uint256 envfree
	getAuctionPriceEnd(uint256) returns uint256 envfree

	token.balanceOf(address) returns uint256 envfree

	// summarize
	getSellerAuctionPrice(uint256 id) => auctionPrice(id)
}

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////

ghost uint8oracle() returns uint8;
ghost uint256oracle() returns uint256;


ghost campaignToBuyer(uint256) returns address;

hook Sload address buyer _buyerCampaigns[KEY uint256 id].(offset 0) STORAGE {
	require campaignToBuyer(id) == buyer;
}

hook Sstore _buyerCampaigns[KEY uint256 id].(offset 0) address buyer STORAGE {
	havoc campaignToBuyer assuming campaignToBuyer@new(id) == buyer &&
		(forall uint256 id2. id != id2 => campaignToBuyer@new(id2) == campaignToBuyer@old(id2));
}


ghost auctionPrice(uint256) returns uint256;

ghost auctionPriceStart(uint256) returns uint256;

hook Sload uint value _sellerAuctions[KEY uint256 id].(offset 64) STORAGE {
	require auctionPriceStart(id) == value;
}

hook Sstore _sellerAuctions[KEY uint256 id].(offset 64) uint value STORAGE {
	havoc auctionPriceStart assuming auctionPriceStart@new(id) == value &&
		(forall uint256 id2. id != id2 => auctionPriceStart@new(id2) == auctionPriceStart@old(id2));
}

// Ghosts are like additional function
// sumDeposits(address user) returns (uint256);
// This ghost represents the sum of all deposits to user
// sumDeposits(s) := sum(...[s].deposits[member] for all addresses member)
/*
ghost sumDeposits(uint256) returns uint {
    init_state axiom forall uint256 s. sumDeposits(s) == 0;
}
*/

ghost buyerCampaignCount() returns uint256;

hook Sstore _buyerCampaignCount uint value STORAGE {
	havoc buyerCampaignCount assuming buyerCampaignCount@new() == value;
}

hook Sload uint value _buyerCampaignCount STORAGE {
	require buyerCampaignCount() == value;
}


////////////////////////////////////////////////////////////////////////////
//                       Invariants                                       //
////////////////////////////////////////////////////////////////////////////



/* 	Rule: title  
 	Description:  
	Formula: 
	Notes: assumptions and simplification more explanations 
*/


invariant auctionHasPricePendingIfAndOnlyIfHasBuyerCampaign(uint256 auctionId)
    getAuctionPricePending(auctionId) != 0 <=> getAuctionBuyerCampaign(auctionId) != 0





function validStateAuction(uint auctionId) {
	require auctionPriceStart(auctionId) >= auctionPrice(auctionId); // TODO: Check in priceShouldAlwaysBeBetweenPriceStartAndPriceEnd
} 

function validStateBuyer(uint campaignId) {
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

////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

function additivity(uint x, uint y, address who, uint32 funcId) {
	storage init = lastStorage;

	callFunctionWithAmountAndSender(funcId, [x], who);
	callFunctionWithAmountAndSender(funcId, [y], who);

	uint splitWho = token.balanceOf(who);
	uint splitMarket = token.balanceOf(currentContract);

	callFunctionWithAmountAndSender(funcId, [x,y], who) at init;
assert false;
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