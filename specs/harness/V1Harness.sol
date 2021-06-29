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

    function getAuctionPriceStart(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , ret, , , , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionPriceEnd(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , , , ret, , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionCampaignApproved(uint256 id) external view returns (uint8) {
        uint8 ret;
        (, , , , , , , , , , ret) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionTimeStart(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , ret, , , , , , , , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionTimeEnd(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , ret, , , , , , , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getContractTimeStart(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , ret, , , , , , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getContractTimeEnd(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , ret, , , , , ) = ZestyMarket_ERC20_V1_1(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionAutoApproveSetting(uint256 tokenId) external view returns (uint256) {
        uint8 ret;
        (, , ret, ) = ZestyMarket_ERC20_V1_1(this).getSellerNFTSetting(tokenId);
        return ret;
    }

    function getSellerByTokenId(uint256 tokenId) external view returns (address) {
        address ret;
        ( , ret, , ) = ZestyMarket_ERC20_V1_1(this).getSellerNFTSetting(tokenId);
        return ret;
    }

    function getInProgress(uint256 tokenId) external view returns (uint256) {
        uint256 ret;
        (, , , ret) = ZestyMarket_ERC20_V1_1(this).getSellerNFTSetting(tokenId);
        return ret;
    }

    function getBuyer(uint256 campaignId) external view returns (address) {
        address ret;
        (ret, ) = ZestyMarket_ERC20_V1_1(this).getBuyerCampaign(campaignId);
        return ret;
    }

    // used for resetting storage in spec
    function dummy() external view {}

}