// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/utils/EnumerableSet.sol";
import "./ZestyVault.sol";

/**
 * @title Zesty Market V1 using ERC20
 * @author Zesty Market
 * @notice 
 *   Deposit ZestyNFTs for Adslots Auctions and Fulfillment.
 *   Primary use-case of the contract is to experiment on UX flow and value transfer.
 *   No validation using shamir secret shares is done in this version
 */
contract ZestyMarket_V1 is Ownable, ZestyVault {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _erc20Address;
    uint256 private _buyerCampaignCount = 1; // 0 is used null values
    uint256 private _sellerAuctionCount = 1; // 0 is used for null values
    uint256 private _contractCount = 0;
    uint8 private constant _FALSE = 1;
    uint8 private constant _TRUE = 2;

    constructor(
        address erc20Address_,
        address zestyNFTAddress_
    ) 
        ZestyVault(zestyNFTAddress_) 
    {
        _erc20Address = erc20Address_;
    }
    
    struct SellerNFTSetting {
        uint256 tokenId;
        address seller;
        uint8 autoApprove;
    }
    mapping (uint256 => SellerNFTSetting) private _sellerNFTSettings; 

    event SellerNFTDeposit(uint256 indexed tokenId, address seller, uint8 autoApprove);
    event SellerNFTUpdate(uint256 indexed tokenId, uint8 autoApprove);
    event SellerNFTWithdraw(uint256 indexed tokenId);

    struct SellerAuction {
        address seller;
        uint256 tokenId;
        uint256 auctionTimeStart;
        uint256 auctionTimeEnd;
        uint256 contractTimeStart;
        uint256 contractTimeEnd;
        uint256 priceStart;
        uint256 priceEnd;
        uint256 buyerCampaign;
        uint8 buyerCampaignApproved;
    }
    mapping (uint256 => SellerAuction) private _sellerAuctions; 

    event SellerAuctionCreate(
        uint256 indexed sellerAuctionId, 
        address seller,
        uint256 tokenId,
        uint256 auctionTimeStart,
        uint256 auctionTimeEnd,
        uint256 contractTimeStart,
        uint256 contractTimeEnd,
        uint256 priceStart,
        uint256 autoApprove
    );
    event SellerAuctionCancel(uint256 indexed sellerAuctionId);
    event SellerAuctionBuyerCampaignNew(
        uint256 indexed sellerAuctionId, 
        uint256 buyerCampaignId,
        uint256 priceEnd
    );
    event SellerAuctionBuyerCampaignApprove(
        uint256 indexed sellerAuctionId, 
        uint256 buyerCampaignId
    );
    event SellerAuctionBuyerCampaignReject(
        uint256 indexed sellerAuctionId, 
        uint256 buyerCampaignId
    );

    struct BuyerCampaign {
        address buyer;
        string uri;
    }
    mapping (uint256 => BuyerCampaign) private _buyerCampaigns;

    event BuyerCampaignCreate(
        uint256 indexed buyerCampaignId, 
        address buyer, 
        string uri
    );
    event BuyerCampaignCancel(uint256 indexed buyerCampaignId);

    struct Contract {
        uint256 sellerAuctionId;
        uint256 buyerCampaignId;
        uint256 contractTimeStart;
        uint256 contractTimeEnd;
        uint256 contractValue;
        uint8 withdrawn;
    }

    mapping (uint256 => Contract) private _contracts; 

    event ContractCreate (
        uint256 indexed contractId,
        uint256 sellerAuctionId,
        uint256 buyerCampaignId,
        uint256 contractTimeStart,
        uint256 contractTimeEnd,
        uint256 contractValue
    );
    event ContractWithdraw(uint256 indexed contractId);

    function getERC20Address() public view returns (address) {
        return _erc20Address;
    }

    function getSellerAuctionPrice(uint256 _sellerAuctionId) public view returns (uint256) {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        uint256 timeNow = block.timestamp;

        uint256 timePassed = timeNow.sub(s.auctionTimeStart);
        uint256 timeTotal = s.contractTimeEnd.sub(s.auctionTimeStart);
        uint256 rescalePriceStart = s.priceStart.mul(100000);
        uint256 gradient = rescalePriceStart.div(timeTotal);

        return rescalePriceStart.sub(gradient.mul(timePassed)).div(100000);
    }

    function getSellerAuction(uint256 _sellerAuctionId) 
        public 
        view 
        returns (
            address seller,
            uint256 tokenId,
            uint256 auctionTimeStart,
            uint256 auctionTimeEnd,
            uint256 contractTimeStart,
            uint256 contractTimeEnd,
            uint256 priceStart,
            uint256 priceEnd,
            uint256 buyerCampaign,
            uint8 buyerCampaignApproved
        )
    {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        seller = s.seller;
        tokenId = s.tokenId;
        auctionTimeStart = s.auctionTimeStart;
        auctionTimeEnd = s.auctionTimeEnd;
        contractTimeStart = s.contractTimeStart;
        contractTimeEnd = s.contractTimeEnd;
        priceStart = s.priceStart;
        priceEnd = s.priceEnd;
        buyerCampaign = s.buyerCampaign;
        buyerCampaignApproved = s.buyerCampaignApproved;
    }

    /* 
     * Buyer logic
     */

    function buyerCampaignCreate(string memory _uri) public {
        _buyerCampaigns[_buyerCampaignCount] = BuyerCampaign(
            msg.sender,
            _uri
        );
        emit BuyerCampaignCreate(
            _buyerCampaignCount,
            msg.sender,
            _uri
        );
        _buyerCampaignCount = _buyerCampaignCount.add(1);
    }

    function buyerCampaignCancel(uint256 _buyerCampaignId) public {
        BuyerCampaign storage b = _buyerCampaigns[_buyerCampaignId];
        require(b.buyer == msg.sender, "ZestyMarket_ERC20_V1: Not buyer");
        delete _buyerCampaigns[_buyerCampaignId];
        emit BuyerCampaignCancel(_buyerCampaignId);
    }
    /* 
     * Seller logic
     */
    function sellerNFTDeposit(
        uint256 _tokenId,
        uint8 _autoApprove
    ) public {
        require(
            _autoApprove == _TRUE || _autoApprove == _FALSE,
            "ZestyMarket_ERC20_V1: _autoApprove must be uint8 1 (FALSE) or 2 (TRUE)"
        );
        _depositZestyNFT(_tokenId);

        _sellerNFTSettings[_tokenId] = SellerNFTSetting(
            _tokenId,
            msg.sender, 
            _autoApprove
        );

        emit SellerNFTDeposit(
            _tokenId,
            msg.sender,
            _autoApprove
        );
    }

    function sellerNFTWithdraw(uint256 _tokenId) public onlyDepositor(_tokenId) {
        _withdrawZestyNFT(_tokenId);
        delete _sellerNFTSettings[_tokenId];
        emit SellerNFTWithdraw(_tokenId);
    }

    function updateZestyNFT(
        uint256 _tokenId,
        uint8 _autoApprove
    ) 
        public
        onlyDepositor(_tokenId)
    {
        require(
            _autoApprove == _TRUE || _autoApprove == _FALSE,
            "ZestyMarket_ERC20_V1: _autoApprove must be uint8 1 (FALSE) or 2 (TRUE)"
        );
        _sellerNFTSettings[_tokenId] = SellerNFTSetting(
            _tokenId,
            msg.sender,
            _autoApprove
        );

        emit SellerNFTUpdate(
            _tokenId,
            _autoApprove
        );
    }

    function _sellerAuctionCreate(
        address _seller,
        uint256 _tokenId,
        uint256 _auctionTimeStart,
        uint256 _auctionTimeEnd,
        uint256 _contractTimeStart,
        uint256 _contractTimeEnd,
        uint256 _priceStart
    )
        private
    {
        require(
            _priceStart > 0, 
            "ZestyMarket_ERC20_V1: Starting Price of the Auction must be greater than 0"
        );
        require(
            _auctionTimeStart > block.timestamp,
            "ZestyMarket_ERC20_V1: Starting time of the Auction must be greater than current block timestamp"
        );
        require(
            _auctionTimeEnd > _auctionTimeStart,
            "ZestyMarket_ERC20_V1: Ending time of the Auction must be greater than the starting time of Auction"
        );
        require(
            _contractTimeStart > _auctionTimeStart,
            "ZestyMarket_ERC20_V1: Starting time of the Contract must be greater than the starting time of Auction"
        );
        require(
            _contractTimeEnd > _auctionTimeStart,
            "ZestyMarket_ERC20_V1: Ending time of the Contract must be greater than the starting time of Contract"
        );
        require(
            _contractTimeEnd > _auctionTimeEnd,
            "ZestyMarket_ERC20_V1: Ending time of the Contract must be greater than the ending time of Auction"
        );

        SellerNFTSetting storage s = _sellerNFTSettings[_tokenId];
        
        _sellerAuctions[_sellerAuctionCount] = SellerAuction(
            _seller,
            _tokenId,
            _auctionTimeStart,
            _auctionTimeEnd,
            _contractTimeStart,
            _contractTimeEnd,
            _priceStart,
            0,
            0,
            s.autoApprove
        );

        emit SellerAuctionCreate(
            _sellerAuctionCount,
            _seller,
            _tokenId,
            _auctionTimeStart,
            _auctionTimeEnd,
            _contractTimeStart,
            _contractTimeEnd,
            _priceStart,
            s.autoApprove
        );

        _sellerAuctionCount = _sellerAuctionCount.add(1);

    }

    function sellerAuctionCreate(
        uint256 _tokenId,
        uint256 _auctionTimeStart,
        uint256 _auctionTimeEnd,
        uint256 _contractTimeStart,
        uint256 _contractTimeEnd,
        uint256 _priceStart
    ) 
        external
        onlyDepositor(_tokenId)
    {
        _sellerAuctionCreate(
            msg.sender,
            _tokenId,
            _auctionTimeStart,
            _auctionTimeEnd,
            _contractTimeStart,
            _contractTimeEnd,
            _priceStart
        );
    }

    function sellerAuctionCreateBatch(
        uint256 _tokenId,
        uint256[] memory _auctionTimeStart,
        uint256[] memory _auctionTimeEnd,
        uint256[] memory _contractTimeStart,
        uint256[] memory _contractTimeEnd,
        uint256[] memory _priceStart
    ) 
        external 
        onlyDepositor(_tokenId)
    {
        require(
            _auctionTimeStart.length == _auctionTimeEnd.length && 
            _auctionTimeEnd.length == _contractTimeStart.length &&
            _contractTimeStart.length == _contractTimeEnd.length &&
            _contractTimeEnd.length == _priceStart.length,
            "ZestyMarket_ERC20_V1: Array length not equal"
        );
        for (uint i=0; i < _auctionTimeStart.length; i++) {
            _sellerAuctionCreate(
                msg.sender,
                _tokenId,
                _auctionTimeStart[i],
                _auctionTimeEnd[i],
                _contractTimeStart[i],
                _contractTimeEnd[i],
                _priceStart[i]
            );
        }
    }
    function _sellerAuctionCancel(uint256 _sellerAuctionId) private {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        require(s.seller != address(0), "ZestyMarket_ERC20_V1: Seller Auction is invalid");
        require(s.buyerCampaign == 0, "ZestyMarket_ERC20_V1: Reject campaign before cancelling");
        require(s.seller == msg.sender, "ZestyMarket_ERC20_V1: Not seller");
        delete _sellerAuctions[_sellerAuctionId];
        emit SellerAuctionCancel(_sellerAuctionId);
    }

    function sellerAuctionCancel(uint256 _sellerAuctionId) public {
        _sellerAuctionCancel(_sellerAuctionId);
    }

    function sellerAuctionCancelBatch(uint256[] memory _sellerAuctionId) public {
        for(uint i=0; i < _sellerAuctionId.length; i++) {
            _sellerAuctionCancel(_sellerAuctionId[i]);
        }
    }

    function _sellerAuctionBid(uint256 _sellerAuctionId, uint256 _buyerCampaignId) private {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        BuyerCampaign storage b = _buyerCampaigns[_buyerCampaignId];
        require(s.seller != address(0), "ZestyMarket_ERC20_V1: Seller Auction is invalid");
        require(s.seller != msg.sender, "ZestyMarket_ERC20_V1: Can't bid on own auction");
        require(s.buyerCampaign == 0, "ZestyMarket_ERC20_V1: Already has a bid");
        require(b.buyer != address(0), "ZestyMarket_ERC20_V1: Buyer Campaign is invalid");

        s.buyerCampaign = _buyerCampaignId;

        uint256 price = getSellerAuctionPrice(_sellerAuctionId);
        s.priceEnd = price;

        if(!IERC20(_erc20Address).transferFrom(msg.sender, address(this), price)) {
            revert("Transfer of ERC20 failed, check if sufficient allowance is provided");
        }

        emit SellerAuctionBuyerCampaignNew(
            _sellerAuctionId,
            _buyerCampaignId,
            price
        );

        if (s.buyerCampaignApproved == _TRUE) {
            _contracts[_contractCount] = Contract(
                _sellerAuctionId,
                _buyerCampaignId,
                s.contractTimeStart,
                s.contractTimeEnd,
                price,
                _FALSE
            );

            emit SellerAuctionBuyerCampaignApprove(
                _sellerAuctionId,
                _buyerCampaignId
            );
            emit ContractCreate(
                _contractCount,
                _sellerAuctionId,
                _buyerCampaignId,
                s.contractTimeStart,
                s.contractTimeEnd,
                price
            );
            _contractCount = _contractCount.add(1);
        }
    }

    function sellerAuctionBid(uint256 _sellerAuctionId, uint256 _buyerCampaignId) public {
        _sellerAuctionBid(_sellerAuctionId, _buyerCampaignId);
    }

    function sellerAuctionBidBatch(uint256[] memory _sellerAuctionId, uint256 _buyerCampaignId) public {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            _sellerAuctionBid(_sellerAuctionId[i], _buyerCampaignId);
        }
    }

    function _sellerAuctionApprove(uint256 _sellerAuctionId) private {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        require(s.seller != address(0), "ZestyMarket_ERC20_V1: Seller Auction is invalid");
        require(s.seller == msg.sender, "ZestyMarket_ERC20_V1: Not Seller");
        require(s.buyerCampaign != 0, "ZestyMarket_ERC20_V1: Does not have a bid");
        require(s.buyerCampaignApproved == _FALSE, "ZestyMarket_ERC20_V1: Already approved");

        s.buyerCampaignApproved == _TRUE;
        _contracts[_contractCount] = Contract(
            _sellerAuctionId,
            s.buyerCampaign,
            s.contractTimeStart,
            s.contractTimeEnd,
            s.priceEnd,
            _FALSE
        );

        emit SellerAuctionBuyerCampaignApprove(
            _sellerAuctionId,
            s.buyerCampaign
        );
        emit ContractCreate(
            _contractCount,
            _sellerAuctionId,
            s.buyerCampaign,
            s.contractTimeStart,
            s.contractTimeEnd,
            s.priceEnd
        );
        _contractCount = _contractCount.add(1);
    }

    function sellerAuctionApprove(uint256 _sellerAuctionId) public {
        _sellerAuctionApprove(_sellerAuctionId);
    }

    function sellerAuctionApproveBatch(uint256[] memory _sellerAuctionId) public {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            _sellerAuctionApprove(_sellerAuctionId[i]);
        }
    }

    function _sellerAuctionReject(uint256 _sellerAuctionId) private {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        require(s.seller != address(0), "ZestyMarket_ERC20_V1: Seller Auction is invalid");
        require(s.seller == msg.sender, "ZestyMarket_ERC20_V1: Not Seller");
        require(s.buyerCampaign != 0, "ZestyMarket_ERC20_V1: Does not have a bid");
        require(s.buyerCampaignApproved == _FALSE, "ZestyMarket_ERC20_V1: Already approved");

        BuyerCampaign storage b = _buyerCampaigns[s.buyerCampaign];
        uint256 priceEnd = s.priceEnd;
        s.priceEnd = 0;
        s.buyerCampaign = 0;

        if(!IERC20(_erc20Address).transferFrom(address(this), b.buyer, priceEnd)) {
            revert("Transfer of ERC20 failed, check if sufficient allowance is provided");
        }

        emit SellerAuctionBuyerCampaignReject(_sellerAuctionId, s.buyerCampaign);
    }

    function sellerAuctionReject(uint256 _sellerAuctionId) public {
        _sellerAuctionReject(_sellerAuctionId);
    }

    function sellerAuctionRejectBatch(uint256[] memory _sellerAuctionId) public {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            _sellerAuctionReject(_sellerAuctionId[i]);
        }
    }

    function _contractWithdraw(uint256 _contractId) private {
        Contract storage c = _contracts[_contractId];
        SellerAuction storage s = _sellerAuctions[c.sellerAuctionId];

        require(s.seller != address(0), "ZestyMarket_ERC20_V1: Seller Auction is invalid");
        require(s.seller == msg.sender, "ZestyMarket_ERC20_V1: Not Seller");
        require(c.sellerAuctionId != 0 || c.buyerCampaignId != 0, "ZestyMarket_ERC20_V1: Invalid Contract");
        require(block.timestamp > c.contractTimeEnd, "ZestyMarket_ERC20_V1: Contract has not ended");
        require(c.withdrawn == _FALSE, "ZestyMarket_ERC20_V1: Already withdrawn");

        c.withdrawn = _TRUE;
        if(!IERC20(_erc20Address).transferFrom(address(this), s.seller, c.contractValue)) {
            revert("Transfer of ERC20 failed, check if sufficient allowance is provided");
        }

        emit ContractWithdraw(_contractId);
    }

    function contractWithdraw(uint256 _contractId) public {
        _contractWithdraw(_contractId);
    }

    function contractWithdrawBatch(uint256[] memory _contractId) public {
        for(uint i=0; i < _contractId.length; i++) {
            _contractWithdraw(_contractId[i]);
        }
    }
}
