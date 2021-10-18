// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

interface IZestyMarket_ERC20_V1_1 {
    function getTxTokenAddress() external view returns (address);
    function getZestyCut() external view returns (uint256);
    function getSellerNFTSetting(uint256 _tokenId)
        external 
        view 
        returns(
            uint256 tokenId,
            address seller,
            uint8 autoApprove,
            uint256 inProgressCount
        );
    function getSellerAuctionPrice(uint256 _sellerAuctionId) external view returns (uint256);
    function getSellerAuction(uint256 _sellerAuctionId) 
        external 
        view 
        returns (
            address seller,
            uint256 tokenId,
            uint256 auctionTimeStart,
            uint256 auctionTimeEnd,
            uint256 contractTimeStart,
            uint256 contractTimeEnd,
            uint256 priceStart,
            uint256 pricePending,
            uint256 priceEnd,
            uint256 buyerCampaign,
            uint8 buyerCampaignApproved
        );   
    function getBuyerCampaign(uint256 _buyerCampaignId)
        external
        view
        returns (
            address buyer,
            string memory uri
        );
    function getContract(uint256 _contractId)
        external
        view
        returns (
            uint256 sellerAuctionId,
            uint256 buyerCampaignId,
            uint256 contractTimeStart,
            uint256 contractTimeEnd,
            uint256 contractValue,
            uint8 withdrawn
        );
    function buyerCampaignCreate(string memory _uri) external;
    function sellerNFTDeposit(
        uint256 _tokenId,
        uint8 _autoApprove
    ) 
        external;
    function sellerNFTWithdraw(uint256 _tokenId) external;
    function sellerNFTUpdate(
        uint256 _tokenId,
        uint8 _autoApprove
    ) 
        external;    
    function sellerAuctionCreateBatch(
        uint256 _tokenId,
        uint256[] memory _auctionTimeStart,
        uint256[] memory _auctionTimeEnd,
        uint256[] memory _contractTimeStart,
        uint256[] memory _contractTimeEnd,
        uint256[] memory _priceStart
    ) 
        external;
    function sellerAuctionCancelBatch(uint256[] memory _sellerAuctionId) external;
    function sellerAuctionBidBatch(uint256[] memory _sellerAuctionId, uint256 _buyerCampaignId) external;
    function sellerAuctionBidCancelBatch(uint256[] memory _sellerAuctionId) external;
    function sellerAuctionApproveBatch(uint256[] memory _sellerAuctionId) external;
    function sellerAuctionRejectBatch(uint256[] memory _sellerAuctionId) external;
    function contractWithdrawBatch(uint256[] memory _contractId) external;
}
