// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../utils/SafeMath.sol";
import "../utils/ReentrancyGuard.sol";
import "../interfaces/IERC20.sol";
import "./ZestyVault.sol";

contract ZestyMarket_ERC20_V2 is ZestyVault, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _erc20Address;
    address private _validator;
    uint256 private _buyerCampaignCount = 1; // 0 is used null values
    uint256 private _sellerAuctionCount = 1; // 0 is used for null values
    uint256 private _contractCount = 1;
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
        uint256 inProgressCount;
    }
    mapping (uint256 => SellerNFTSetting) private _sellerNFTSettings; 

    event SellerNFTDeposit(uint256 indexed tokenId, address seller, uint8 autoApprove);
    event SellerNFTUpdate(uint256 indexed tokenId, uint8 autoApprove, uint256 inProgressCount);
    event SellerNFTWithdraw(uint256 indexed tokenId);

    struct SellerAuction {
        address seller;
        uint256 tokenId;
        uint256 auctionTimeStart;
        uint256 auctionTimeEnd;
        uint256 contractTimeStart;
        uint256 contractTimeEnd;
        uint256 priceStart;
        uint256 pricePending;
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
        uint8 buyerCampaignApproved
    );
    event SellerAuctionCancel(uint256 indexed sellerAuctionId);
    event SellerAuctionBuyerCampaignNew(
        uint256 indexed sellerAuctionId, 
        uint256 buyerCampaignId,
        uint256 pricePending
    );
    event SellerAuctionBuyerCampaignBuyerCancel(uint256 indexed sellerAuctionId);
    event SellerAuctionBuyerCampaignApprove( uint256 indexed sellerAuctionId, uint256 priceEnd);
    event SellerAuctionBuyerCampaignReject( uint256 indexed sellerAuctionId);

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

    function getERC20Address() external view returns (address) {
        return _erc20Address;
    }

    function getSellerNFTSetting(uint256 _tokenId) 
        external 
        view
        returns (
            uint256 tokenId,
            address seller,
            uint8 autoApprove,
            uint256 inProgressCount
        ) 
    {
        tokenId = _sellerNFTSettings[_tokenId].tokenId;
        seller = _sellerNFTSettings[_tokenId].seller;
        autoApprove = _sellerNFTSettings[_tokenId].autoApprove;
        inProgressCount = _sellerNFTSettings[_tokenId].inProgressCount;
    }

    function getSellerAuctionPrice(uint256 _sellerAuctionId) public view returns (uint256) {
        SellerAuction storage s = _sellerAuctions[_sellerAuctionId];
        uint256 timeNow = block.timestamp;
        uint256 timeTotal = s.contractTimeEnd.sub(s.auctionTimeStart);
        uint256 rescalePriceStart = s.priceStart.mul(100000);
        uint256 gradient = rescalePriceStart.div(timeTotal);

        return rescalePriceStart.sub(gradient.mul(timeNow.sub(s.auctionTimeStart))).div(100000);
    }

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
        )
    {
        seller = _sellerAuctions[_sellerAuctionId].seller;
        tokenId = _sellerAuctions[_sellerAuctionId].tokenId;
        auctionTimeStart = _sellerAuctions[_sellerAuctionId].auctionTimeStart;
        auctionTimeEnd = _sellerAuctions[_sellerAuctionId].auctionTimeEnd;
        contractTimeStart = _sellerAuctions[_sellerAuctionId].contractTimeStart;
        contractTimeEnd = _sellerAuctions[_sellerAuctionId].contractTimeEnd;
        priceStart = _sellerAuctions[_sellerAuctionId].priceStart;
        pricePending = _sellerAuctions[_sellerAuctionId].pricePending;
        priceEnd = _sellerAuctions[_sellerAuctionId].priceEnd;
        buyerCampaign = _sellerAuctions[_sellerAuctionId].buyerCampaign;
        buyerCampaignApproved = _sellerAuctions[_sellerAuctionId].buyerCampaignApproved;
    }

    function getBuyerCampaign(uint256 _buyerCampaignId)
        external
        view
        returns (
            address buyer,
            string memory uri
        )
    {
        buyer = _buyerCampaigns[_buyerCampaignId].buyer;
        uri = _buyerCampaigns[_buyerCampaignId].uri;
    }

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
        )
    {
        sellerAuctionId = _contracts[_contractId].sellerAuctionId;
        buyerCampaignId = _contracts[_contractId].buyerCampaignId;
        contractTimeStart = _contracts[_contractId].contractTimeStart;
        contractTimeEnd = _contracts[_contractId].contractTimeEnd;
        contractValue = _contracts[_contractId].contractValue;
        withdrawn = _contracts[_contractId].withdrawn;
    }

    /* 
     * Buyer logic
     */

    function buyerCampaignCreate(string memory _uri) external {
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

    /* 
     * Seller logic
     */
    function sellerNFTDeposit(
        uint256 _tokenId,
        uint8 _autoApprove
    ) 
        external 
        nonReentrant
    {
        require(
            _autoApprove == _TRUE || _autoApprove == _FALSE,
            "ZestyMarket_ERC20_V1::sellerNFTDeposit: _autoApprove must be uint8 1 (FALSE) or 2 (TRUE)"
        );
        _depositZestyNFT(_tokenId);

        _sellerNFTSettings[_tokenId] = SellerNFTSetting(
            _tokenId,
            msg.sender, 
            _autoApprove,
            0
        );

        emit SellerNFTDeposit(
            _tokenId,
            msg.sender,
            _autoApprove
        );
    }

    function sellerNFTWithdraw(uint256 _tokenId) external onlyDepositor(_tokenId) nonReentrant {
        SellerNFTSetting storage s = _sellerNFTSettings[_tokenId];
        require(
            s.inProgressCount == 0, 
            "ZestyMarket_ERC20_V1::sellerNFTWithdraw Auction or Contact is in progress withdraw"
        );
        _withdrawZestyNFT(_tokenId);
        delete _sellerNFTSettings[_tokenId];
        emit SellerNFTWithdraw(_tokenId);
    }

    function sellerNFTUpdate(
        uint256 _tokenId,
        uint8 _autoApprove
    ) 
        external
        onlyDepositorOrOperator(_tokenId)
    {
        require(
            _autoApprove == _TRUE || _autoApprove == _FALSE,
            "ZestyMarket_ERC20_V1::sellerNFTUpdate _autoApprove must be uint8 1 (FALSE) or 2 (TRUE)"
        );
        SellerNFTSetting storage s = _sellerNFTSettings[_tokenId];
        s.autoApprove = _autoApprove;

        emit SellerNFTUpdate(
            _tokenId,
            _autoApprove,
            s.inProgressCount
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
        onlyDepositorOrOperator(_tokenId)
    {
        require(
            _auctionTimeStart.length == _auctionTimeEnd.length && 
            _auctionTimeEnd.length == _contractTimeStart.length &&
            _contractTimeStart.length == _contractTimeEnd.length &&
            _contractTimeEnd.length == _priceStart.length,
            "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Array length not equal"
        );

        address _seller = getDepositor(_tokenId);

        for (uint i=0; i < _auctionTimeStart.length; i++) {
            require(
                _priceStart[i] > 0, 
                "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Starting Price of the Auction must be greater than 0"
            );
            require(
                _auctionTimeStart[i] > block.timestamp,
                "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Starting time of the Auction must be greater than current block timestamp"
            );
            require(
                _auctionTimeEnd[i] > _auctionTimeStart[i],
                "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Ending time of the Auction must be greater than the starting time of Auction"
            );
            require(
                _contractTimeStart[i] > _auctionTimeStart[i],
                "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Starting time of the Contract must be greater than the starting time of Auction"
            );
            require(
                _contractTimeEnd[i] > _auctionTimeStart[i],
                "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Ending time of the Contract must be greater than the starting time of Contract"
            );
            require(
                _contractTimeEnd[i] > _auctionTimeEnd[i],
                "ZestyMarket_ERC20_V1::sellerAuctionCreateBatch: Ending time of the Contract must be greater than the ending time of Auction"
            );

            SellerNFTSetting storage s = _sellerNFTSettings[_tokenId];
            s.inProgressCount = s.inProgressCount.add(1);

            emit SellerNFTUpdate(
                _tokenId,
                s.autoApprove,
                s.inProgressCount
            );

            
            _sellerAuctions[_sellerAuctionCount] = SellerAuction(
                _seller,
                _tokenId,
                _auctionTimeStart[i],
                _auctionTimeEnd[i],
                _contractTimeStart[i],
                _contractTimeEnd[i],
                _priceStart[i],
                0,
                0,
                0,
                s.autoApprove
            );

            emit SellerAuctionCreate(
                _sellerAuctionCount,
                _seller,
                _tokenId,
                _auctionTimeStart[i],
                _auctionTimeEnd[i],
                _contractTimeStart[i],
                _contractTimeEnd[i],
                _priceStart[i],
                s.autoApprove
            );

            _sellerAuctionCount = _sellerAuctionCount.add(1);
        }
    }

    function sellerAuctionCancelBatch(uint256[] memory _sellerAuctionId) external {
        for(uint i=0; i < _sellerAuctionId.length; i++) {
            SellerAuction storage s = _sellerAuctions[_sellerAuctionId[i]];
            require(
                s.seller != address(0), 
                "ZestyMarket_ERC20_V1::sellerAuctionCancelBatch: Seller Auction is invalid"
            );
            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V1::sellerAuctionCancelBatch: Not seller or operator for seller"
            );
            require(
                s.buyerCampaign == 0,
                "ZestyMarket_ERC20_V1::sellerAuctionCancelBatch: Reject buyer campaign before cancelling"
            );
            delete _sellerAuctions[_sellerAuctionId[i]];

            SellerNFTSetting storage se = _sellerNFTSettings[s.tokenId];
            se.inProgressCount = se.inProgressCount.sub(1);
            emit SellerAuctionCancel(_sellerAuctionId[i]);
            emit SellerNFTUpdate(
                se.tokenId,
                se.autoApprove,
                se.inProgressCount
            );
        }
    }

    function sellerAuctionBidBatch(uint256[] memory _sellerAuctionId, uint256 _buyerCampaignId) external nonReentrant {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            SellerAuction storage s = _sellerAuctions[_sellerAuctionId[i]];
            BuyerCampaign storage b = _buyerCampaigns[_buyerCampaignId];
            require(
                block.timestamp >= s.auctionTimeStart, 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Auction has yet to start"
            );
            require(
                s.auctionTimeEnd >= block.timestamp, 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Auction has ended"
            );
            require(
                s.seller != address(0), 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Seller Auction is invalid"
            );
            require(
                s.seller != msg.sender, 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Cannot bid on own auction"
            );
            require(
                s.buyerCampaign == 0, 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Already has a bid"
            );
            require(
                b.buyer != address(0), 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Buyer Campaign is invalid"
            );
            require(
                b.buyer == msg.sender || isOperator(b.buyer, msg.sender), 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Not buyer or operator for buyer"
            );

            s.buyerCampaign = _buyerCampaignId;

            uint256 price = getSellerAuctionPrice(_sellerAuctionId[i]);
            require(
                price > 0, 
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch: Auction has expired"
            );
            s.pricePending = price;

            require(
                IERC20(_erc20Address).transferFrom(b.buyer, address(this), price),
                "ZestyMarket_ERC20_V1::sellerAuctionBidBatch Transfer of ERC20 failed, check if sufficient allowance is provided"
            );

            emit SellerAuctionBuyerCampaignNew(
                _sellerAuctionId[i],
                _buyerCampaignId,
                price
            );

            // if auto approve is set to true
            if (s.buyerCampaignApproved == _TRUE) {
                _contracts[_contractCount] = Contract(
                    _sellerAuctionId[i],
                    _buyerCampaignId,
                    s.contractTimeStart,
                    s.contractTimeEnd,
                    price,
                    _FALSE
                );

                emit SellerAuctionBuyerCampaignApprove( _sellerAuctionId[i], price);
                emit ContractCreate(
                    _contractCount,
                    _sellerAuctionId[i],
                    _buyerCampaignId,
                    s.contractTimeStart,
                    s.contractTimeEnd,
                    price
                );
                _contractCount = _contractCount.add(1);
            }
        }
    }

    function sellerAuctionBidCancelBatch(uint256[] memory _sellerAuctionId) external nonReentrant {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            BuyerCampaign storage b = _buyerCampaigns[_sellerAuctions[_sellerAuctionId[i]].buyerCampaign];
            require(
                _sellerAuctions[_sellerAuctionId[i]].seller != address(0), 
                "ZestyMarket_ERC20_V1::sellerAuctionBidCancelBatch: Seller Auction is invalid");
            require(
                msg.sender == b.buyer || isOperator(b.buyer, msg.sender), 
                "ZestyMarket_ERC20_V1::sellerAuctionBidCancelBatch: Not buyer or operator for buyer"
            );
            require(
                _sellerAuctions[_sellerAuctionId[i]].buyerCampaignApproved == _FALSE, 
                "ZestyMarket_ERC20_V1::sellerAuctionBidCancelBatch: Seller has approved"
            );

            uint256 pricePending = _sellerAuctions[_sellerAuctionId[i]].pricePending;
            _sellerAuctions[_sellerAuctionId[i]].pricePending = 0;
            _sellerAuctions[_sellerAuctionId[i]].buyerCampaign = 0;

            require(
                IERC20(_erc20Address).transfer(b.buyer, pricePending),
                "ZestyMarket_ERC20_V1::sellerAuctionBidCancelBatch: Transfer of ERC20 failed"
            );

            emit SellerAuctionBuyerCampaignBuyerCancel(_sellerAuctionId[i]);
        }
    }

    function sellerAuctionApproveBatch(uint256[] memory _sellerAuctionId) external nonReentrant {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            SellerAuction storage s = _sellerAuctions[_sellerAuctionId[i]];
            require(
                s.seller != address(0), 
                "ZestyMarket_ERC20_V1::sellerAuctionApproveBatch: Seller auction is invalid"
            );
            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V1::sellerAuctionApproveBatch: Not seller or operator for seller"
            );
            require(
                s.buyerCampaign != 0, 
                "ZestyMarket_ERC20_V1::sellerAuctionApproveBatch: Does not have a bid"
            );
            require(
                s.buyerCampaignApproved == _FALSE, 
                "ZestyMarket_ERC20_V1::sellerAuctionApproveBatch: Already approved"
            );

            uint256 price = getSellerAuctionPrice(_sellerAuctionId[i]);
            require(
                price > 0, 
                "ZestyMarket_ERC20_V1::sellerAuctionApproveBatch: Auction has expired"
            );

            s.priceEnd = price;
            uint256 priceDiff = s.pricePending.sub(s.priceEnd);
            s.pricePending = 0;

            require(
                IERC20(_erc20Address).transfer(_buyerCampaigns[s.buyerCampaign].buyer, priceDiff),
                "ZestyMarket_ERC20_V1::sellerAuctionApproveBatch: Transfer of ERC20 failed"
            );

            s.buyerCampaignApproved = _TRUE;
            _contracts[_contractCount] = Contract(
                _sellerAuctionId[i],
                s.buyerCampaign,
                s.contractTimeStart,
                s.contractTimeEnd,
                s.priceEnd,
                _FALSE
            );

            emit SellerAuctionBuyerCampaignApprove( _sellerAuctionId[i], s.priceEnd);
            emit ContractCreate(
                _contractCount,
                _sellerAuctionId[i],
                s.buyerCampaign,
                s.contractTimeStart,
                s.contractTimeEnd,
                s.priceEnd
            );
            _contractCount = _contractCount.add(1);
        }
    }

    function sellerAuctionRejectBatch(uint256[] memory _sellerAuctionId) external nonReentrant {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            SellerAuction storage s = _sellerAuctions[_sellerAuctionId[i]];
            require(
                s.seller != address(0), 
                "ZestyMarket_ERC20_V1::sellerAuctionRejectBatch: Seller auction is invalid"
            );
            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V1::sellerAuctionRejectBatch: Not seller or operator for seller"
            );
            require(
                s.buyerCampaign != 0, 
                "ZestyMarket_ERC20_V1::sellerAuctionRejectBatch: Does not have a bid"
            );
            require(
                s.buyerCampaignApproved == _FALSE,
                "ZestyMarket_ERC20_V1::sellerAuctionRejectBatch: Already approved"
            );

            uint256 pricePending = s.pricePending;
            s.pricePending = 0;

            require(
                IERC20(_erc20Address).transfer(_buyerCampaigns[s.buyerCampaign].buyer, pricePending),
                "ZestyMarket_ERC20_V1::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );

            s.buyerCampaign = 0;

            emit SellerAuctionBuyerCampaignReject(_sellerAuctionId[i]);
        }
    }

    function contractWithdrawBatch(uint256[] memory _contractId) external nonReentrant {
        for(uint i=0; i < _contractId.length; i++) {
            Contract storage c = _contracts[_contractId[i]];
            SellerAuction storage s = _sellerAuctions[c.sellerAuctionId];

            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V1::contractWithdrawBatch: Not seller or operator"
            );
            require(
                c.sellerAuctionId != 0 || c.buyerCampaignId != 0,
                "ZestyMarket_ERC20_V1::contractWithdrawBatch: Invalid contract"
            );
            require(
                block.timestamp > c.contractTimeEnd, 
                "ZestyMarket_ERC20_V1::contractWithdrawBatch: Contract has not ended"
            );
            require(
                c.withdrawn == _FALSE, 
                "ZestyMarket_ERC20_V1::contractWithdrawBatch: Already withdrawn"
            );

            c.withdrawn = _TRUE;

            require(
                IERC20(_erc20Address).transfer(s.seller, c.contractValue),
                "ZestyMarket_ERC20_V1::contractWithdrawBatch: Transfer of ERC20 failed"

            );

            SellerNFTSetting storage se = _sellerNFTSettings[s.tokenId];
            se.inProgressCount = se.inProgressCount.sub(1);

            emit SellerNFTUpdate(
                se.tokenId,
                se.autoApprove,
                se.inProgressCount
            );

            emit ContractWithdraw(_contractId[i]);
        }
    }
}
