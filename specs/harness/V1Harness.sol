pragma solidity ^0.7.6;

import "../../contracts/market/ZestyMarket_ERC20_V1_1.sol";

contract V1Harness is ZestyMarket_ERC20_V1_1 {

    constructor(
        address txTokenAddress_,
        address zestyNFTAddress_
    ) 
        ZestyMarket_ERC20_V1_1(txTokenAddress_, zestyNFTAddress_) 
    {
    }

    function getAuctionPricePending(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , , ret, , , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionBuyerCampaign(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , , , , ret, ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }
}