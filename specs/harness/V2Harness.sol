pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../../contracts/market/ZestyMarket_ERC20_V2.sol";

contract V2Harness is ZestyMarket_ERC20_V2 {

    constructor(
        address txTokenAddress_,
        address zestyNFTAddress_,
        address rewardsTokenAddress_,
        address zestyDAO_,
        address validator_,
        address rewardsDistributor_,
        uint256 rewardsRateBuyer_,
        uint256 rewardsRateSeller_,
        uint256 rewardsRateValidator_,
        uint256 rewardsRateNFT_
    ) 
        ZestyMarket_ERC20_V2(
            txTokenAddress_,
            zestyNFTAddress_,
            rewardsTokenAddress_,
            zestyDAO_,
            validator_,
            rewardsDistributor_,
            rewardsRateBuyer_,
            rewardsRateSeller_,
            rewardsRateValidator_,
            rewardsRateNFT_
        ) 
    {
    }

    function getAuctionPricePending(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , , ret, , , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionBuyerCampaign(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , , , , ret, ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionPriceStart(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , ret, , , , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionPriceEnd(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , , , , ret, , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionCampaignApproved(uint256 id) external view returns (uint8) {
        uint8 ret;
        (, , , , , , , , , , ret) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionTimeStart(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , ret, , , , , , , , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionTimeEnd(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , ret, , , , , , , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getContractTimeStart(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , ret, , , , , , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getContractTimeEnd(uint256 id) external view returns (uint256) {
        uint256 ret;
        (, , , , , ret, , , , , ) = ZestyMarket_ERC20_V2(this).getSellerAuction(id);
        return ret;
    }

    function getAuctionAutoApproveSetting(uint256 tokenId) external view returns (uint256) {
        uint8 ret;
        (, , ret, ) = ZestyMarket_ERC20_V2(this).getSellerNFTSetting(tokenId);
        return ret;
    }

    function getSellerByTokenId(uint256 tokenId) external view returns (address) {
        address ret;
        ( , ret, , ) = ZestyMarket_ERC20_V2(this).getSellerNFTSetting(tokenId);
        return ret;
    }

    function getInProgress(uint256 tokenId) external view returns (uint256) {
        uint256 ret;
        (, , , ret) = ZestyMarket_ERC20_V2(this).getSellerNFTSetting(tokenId);
        return ret;
    }

    function getBuyer(uint256 campaignId) external view returns (address) {
        address ret;
        (ret, ) = ZestyMarket_ERC20_V2(this).getBuyerCampaign(campaignId);
        return ret;
    }

    // used for resetting storage in spec
    function dummy() external {}

}

