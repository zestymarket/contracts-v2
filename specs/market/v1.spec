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
}

////////////////////////////////////////////////////////////////////////////
//                       Ghost                                            //
////////////////////////////////////////////////////////////////////////////

ghost uint8oracle() returns uint8;
ghost uint256oracle() returns uint256;

// Ghosts are like additional function
// sumDeposits(address user) returns (uint256);
// This ghost represents the sum of all deposits to user
// sumDeposits(s) := sum(...[s].deposits[member] for all addresses member)
/*
ghost sumDeposits(uint256) returns uint {
    init_state axiom forall uint256 s. sumDeposits(s) == 0;
}
*/



// whenever there ia an update to
//     contractmap[user].deposits[memberAddress] := value
// where previously contractmap[user].deposits[memberAddress] was old_value
// update sumDeposits := sumDeposits - old_value + value
/*hook Sstore contractmap[KEY uint256 s].(offset 0)[KEY uint256 member] uint value (uint old_value) STORAGE {
    havoc sumDeposits assuming sumDeposits@new(s) == sumDeposits@old(s) + value - old_value &&
            (forall uint256 other. other != s => sumDeposits@new(other) == sumDeposits@old(other));
}*/



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






/*
function validState(...) {

} 
*/
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
	uint256 _sellerAuctionId;
	uint256 _auctionPriceStart;
	uint256 _auctionPriceEnd;
	uint256 _auctionPrice;

	_auctionPriceStart = getAuctionPriceStart(_sellerAuctionId);
	_auctionPriceEnd = getAuctionPriceEnd(_sellerAuctionId);
	_auctionPrice = getSellerAuctionPrice(e, _sellerAuctionId);

	assert (_auctionPriceStart >= _auctionPrice) && (_auctionPrice >= _auctionPriceEnd);
}

rule bidAdditivity(uint x, uint y, address who) {
	additivity(x, y, who, sellerAuctionBidBatch(uint256[],uint256).selector);
	assert true;
}


////////////////////////////////////////////////////////////////////////////
//                       Helper Functions                                 //
////////////////////////////////////////////////////////////////////////////
    

function additivity(uint x, uint y, address who, uint32 funcId) {
	env e;
	storage init = lastStorage;

	callFunctionWithAmountAndSender(funcId, [x], who);
	callFunctionWithAmountAndSender(funcId, [y], who);

	uint splitWho = token.balanceOf(who);
	uint splitMarket = token.balanceOf(currentContract);

	callFunctionWithAmountAndSender(funcId, [x,y], who) at init;

	uint unifiedWho = token.balanceOf(who);
	uint unifiedMarket = token.balanceOf(currentContract);

	assert splitWho == unifiedWho, "operation is not additive for the given address balance";
	assert splitMarket == unifiedMarket, "operation is not additive for the market balance";
}

function callFunctionWithAmountAndSender(uint32 funcId, uint[] array, address who) {
	if (funcId == sellerAuctionBidBatch(uint256[],uint256).selector) {
		env e;
		require e.msg.sender == who;
		sellerAuctionBidBatch(e, array, uint256oracle());
	} else {
		require false;
	}
}

/*
// easy to use dispatcher
function callFunctionWithParams(address token, address from, address to,
 								uint256 amount, uint256 share, method f) {
	env e;

	if (f.selector == deposit(address, address, address, uint256, uint256).selector) {
		deposit(e, token, from, to, amount, share);
	} else if (f.selector == withdraw(address, address, address, uint256, uint256).selector) {
		withdraw(e, token, from, to, amount, share); 
	} else if  (f.selector == transfer(address, address, address, uint256).selector) {
		transfer(e, token, from, to, share);
	} else {
		calldataarg args;
		f(e,args);
	}
}*/