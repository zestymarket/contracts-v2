// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../utils/SafeMath.sol";
import "../utils/ReentrancyGuard.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IZestyNFT.sol";
import "../governance/RewardsRecipient.sol";
import "./ZestyVault.sol";

contract ZestyMarket_ERC20_V2 is ZestyVault, RewardsRecipient, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _txTokenAddress;
    address private _rewardsTokenAddress;
    IERC20 private _txToken;
    IERC20 private _rewardsToken;
    IZestyNFT private _zestyNFT;
    address private _validator;
    uint256 private _buyerCampaignCount = 1; // 0 is used null values
    uint256 private _sellerAuctionCount = 1; // 0 is used for null values
    uint256 private _contractCount = 1;
    uint8 private constant _FALSE = 1;
    uint8 private constant _TRUE = 2;
    uint256 private _gracePeriod = 172800; // 2 day grace period for seller to withdraw funds
    uint32 private _minAvailabilityThreshold = 7500; // min 75% availablility guaranteed
    uint32 private _validatorCut = 300; // 3% cut for validators
    uint32 private _zestyCut = 300; // 3% cut for zesty dao
    uint256 private _rewardsBalance;
    uint256 private _rewardsRate;  // rewardsToken per txToken

    constructor(
        address zestyNFTAddress_,
        address txTokenAddress_,
        address rewardsTokenAddress_,
        address zestyDAO_,
        address validator_,
        address rewardsDistributor_,
        uint256 rewardsRate_
    ) 
        ZestyVault(zestyNFTAddress_) 
        RewardsRecipient(zestyDAO_, rewardsDistributor_)
    {
        _zestyNFT = IZestyNFT(zestyNFTAddress_);
        _txTokenAddress = txTokenAddress_;
        _txToken = IERC20(txTokenAddress_);
        _rewardsTokenAddress = rewardsTokenAddress_;
        _rewardsToken = IERC20(rewardsTokenAddress_);
        _validator = validator_;
        _rewardsRate = rewardsRate_;
    }
    
    struct SellerNFTSetting {
        uint256 tokenId;
        address seller;
        uint8 autoApprove;
        uint256 inProgressCount;
    }
    mapping (uint256 => SellerNFTSetting) private _sellerNFTSettings; 
    mapping (address => mapping(address => uint8)) private _sellerBans;

    event SellerNFTDeposit(uint256 indexed tokenId, address seller, uint8 autoApprove);
    event SellerNFTUpdate(uint256 indexed tokenId, uint8 autoApprove, uint256 inProgressCount);
    event SellerNFTWithdraw(uint256 indexed tokenId);
    event SellerBan(address indexed seller, address indexed banAddress);
    event SellerUnban(address indexed seller, address indexed banAddress);

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
        uint8 refunded;
        string[] shares;
        uint32 totalShares;
        bytes32 hashlock;
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
    event ContractSetHashlock(
        uint256 indexed contractId,
        bytes32 hashlock,
        uint32 totalShares
    );
    event ContractSetShare(
        uint256 indexed contractId,
        string share
    );
    event ContractWithdraw(uint256 indexed contractId, uint256 nftReward, uint256 sellerReward, uint256 buyerReward);
    event ContractRefund(uint256 indexed contractId);

    event RewardAdded(uint256 reward);

    function getTxTokenAddress() external view returns (address) {
        return _txTokenAddress;
    }

    function getRewardsTokenAddress() external view returns (address) {
        return _rewardsTokenAddress;
    }

    function getValidator() external view returns (address) {
        return _validator;
    }

    function getRewardsBalance() external view returns (uint256) {
        return _rewardsBalance;
    }

    function getRewardsRate() external view returns (uint256) {
        return _rewardsRate;
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
     * Change contract settings
     */
    function setValidator(address validator_) external onlyOwner {
        _validator = validator_;
    }

    function setCuts(uint32 validatorCut_, uint32 zestyCut_) external onlyOwner {
        _validatorCut = validatorCut_;
        _zestyCut = zestyCut_;
    }

    function setMinAvailiblityThreshold(uint32 minAvailabilityThreshold_) external onlyOwner {
        _minAvailabilityThreshold = minAvailabilityThreshold_;
    }

    function setRewardsRate(uint256 rewardsRate_) external onlyOwner {
        _rewardsRate = rewardsRate_;
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
            "ZestyMarket_ERC20_V2::sellerNFTDeposit: _autoApprove must be uint8 1 (FALSE) or 2 (TRUE)"
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
            "ZestyMarket_ERC20_V2::sellerNFTWithdraw Auction or Contact is in progress withdraw"
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
            "ZestyMarket_ERC20_V2::sellerNFTUpdate _autoApprove must be uint8 1 (FALSE) or 2 (TRUE)"
        );
        SellerNFTSetting storage s = _sellerNFTSettings[_tokenId];
        s.autoApprove = _autoApprove;

        emit SellerNFTUpdate(
            _tokenId,
            _autoApprove,
            s.inProgressCount
        );
    }

    function sellerBan(address _addr) external {
        _sellerBans[msg.sender][_addr] = _TRUE;
        emit SellerBan(msg.sender, _addr);
    }

    function sellerUnban(address _addr) external {
        _sellerBans[msg.sender][_addr] = _FALSE;
        emit SellerUnban(msg.sender, _addr);
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
            "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Array length not equal"
        );

        address _seller = getDepositor(_tokenId);

        for (uint i=0; i < _auctionTimeStart.length; i++) {
            require(
                _priceStart[i] > 0, 
                "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Starting Price of the Auction must be greater than 0"
            );
            require(
                _auctionTimeStart[i] > block.timestamp,
                "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Starting time of the Auction must be greater than current block timestamp"
            );
            require(
                _auctionTimeEnd[i] > _auctionTimeStart[i],
                "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Ending time of the Auction must be greater than the starting time of Auction"
            );
            require(
                _contractTimeStart[i] > _auctionTimeStart[i],
                "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Starting time of the Contract must be greater than the starting time of Auction"
            );
            require(
                _contractTimeEnd[i] > _auctionTimeStart[i],
                "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Ending time of the Contract must be greater than the starting time of Contract"
            );
            require(
                _contractTimeEnd[i] > _auctionTimeEnd[i],
                "ZestyMarket_ERC20_V2::sellerAuctionCreateBatch: Ending time of the Contract must be greater than the ending time of Auction"
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
                "ZestyMarket_ERC20_V2::sellerAuctionCancelBatch: Seller Auction is invalid"
            );
            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V2::sellerAuctionCancelBatch: Not seller or operator for seller"
            );
            require(
                s.buyerCampaign == 0,
                "ZestyMarket_ERC20_V2::sellerAuctionCancelBatch: Reject buyer campaign before cancelling"
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
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Auction has yet to start"
            );
            require(
                s.auctionTimeEnd >= block.timestamp, 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Auction has ended"
            );
            require(
                s.seller != address(0), 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Seller Auction is invalid"
            );
            require(
                s.seller != msg.sender, 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Cannot bid on own auction"
            );
            require(
                s.buyerCampaign == 0, 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Already has a bid"
            );
            require(
                b.buyer != address(0), 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Buyer Campaign is invalid"
            );
            require(
                b.buyer == msg.sender || isOperator(b.buyer, msg.sender), 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Not buyer or operator for buyer"
            );
            require(
                _sellerBans[s.seller][b.buyer] != _TRUE,
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Banned by seller"
            );

            s.buyerCampaign = _buyerCampaignId;

            uint256 price = getSellerAuctionPrice(_sellerAuctionId[i]);
            require(
                price > 0, 
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch: Auction has expired"
            );
            s.pricePending = price;

            require(
                _txToken.transferFrom(b.buyer, address(this), price),
                "ZestyMarket_ERC20_V2::sellerAuctionBidBatch Transfer of ERC20 failed, check if sufficient allowance is provided"
            );

            emit SellerAuctionBuyerCampaignNew(
                _sellerAuctionId[i],
                _buyerCampaignId,
                price
            );

            // if auto approve is set to true
            if (s.buyerCampaignApproved == _TRUE) {
                Contract storage c = _contracts[_contractCount];
                c.sellerAuctionId = _sellerAuctionId[i];
                c.buyerCampaignId = _buyerCampaignId;
                c.contractTimeStart = s.contractTimeStart;
                c.contractTimeEnd = s.contractTimeEnd;
                c.contractValue = price;
                c.refunded = _FALSE;
                c.withdrawn = _FALSE;

                emit SellerAuctionBuyerCampaignApprove(_sellerAuctionId[i], price);
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
                "ZestyMarket_ERC20_V2::sellerAuctionBidCancelBatch: Seller Auction is invalid");
            require(
                msg.sender == b.buyer || isOperator(b.buyer, msg.sender), 
                "ZestyMarket_ERC20_V2::sellerAuctionBidCancelBatch: Not buyer or operator for buyer"
            );
            require(
                _sellerAuctions[_sellerAuctionId[i]].buyerCampaignApproved == _FALSE, 
                "ZestyMarket_ERC20_V2::sellerAuctionBidCancelBatch: Seller has approved"
            );

            uint256 pricePending = _sellerAuctions[_sellerAuctionId[i]].pricePending;
            _sellerAuctions[_sellerAuctionId[i]].pricePending = 0;
            _sellerAuctions[_sellerAuctionId[i]].buyerCampaign = 0;

            require(
                _txToken.transfer(b.buyer, pricePending),
                "ZestyMarket_ERC20_V2::sellerAuctionBidCancelBatch: Transfer of ERC20 failed"
            );

            emit SellerAuctionBuyerCampaignBuyerCancel(_sellerAuctionId[i]);
        }
    }

    function sellerAuctionApproveBatch(uint256[] memory _sellerAuctionId) external nonReentrant {
        for (uint i=0; i < _sellerAuctionId.length; i++) {
            SellerAuction storage s = _sellerAuctions[_sellerAuctionId[i]];
            require(
                s.seller != address(0), 
                "ZestyMarket_ERC20_V2::sellerAuctionApproveBatch: Seller auction is invalid"
            );
            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V2::sellerAuctionApproveBatch: Not seller or operator for seller"
            );
            require(
                s.buyerCampaign != 0, 
                "ZestyMarket_ERC20_V2::sellerAuctionApproveBatch: Does not have a bid"
            );
            require(
                s.buyerCampaignApproved == _FALSE, 
                "ZestyMarket_ERC20_V2::sellerAuctionApproveBatch: Already approved"
            );

            uint256 price = getSellerAuctionPrice(_sellerAuctionId[i]);
            require(
                price > 0, 
                "ZestyMarket_ERC20_V2::sellerAuctionApproveBatch: Auction has expired"
            );

            s.priceEnd = price;
            uint256 priceDiff = s.pricePending.sub(s.priceEnd);
            s.pricePending = 0;

            require(
                _txToken.transfer(_buyerCampaigns[s.buyerCampaign].buyer, priceDiff),
                "ZestyMarket_ERC20_V2::sellerAuctionApproveBatch: Transfer of ERC20 failed"
            );

            s.buyerCampaignApproved = _TRUE;
            Contract storage c = _contracts[_contractCount];
            c.sellerAuctionId = _sellerAuctionId[i];
            c.buyerCampaignId = s.buyerCampaign;
            c.contractTimeStart = s.contractTimeStart;
            c.contractTimeEnd = s.contractTimeEnd;
            c.contractValue = s.priceEnd;
            c.withdrawn = _FALSE;
            c.refunded = _FALSE;

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
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Seller auction is invalid"
            );
            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Not seller or operator for seller"
            );
            require(
                s.buyerCampaign != 0, 
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Does not have a bid"
            );
            require(
                s.buyerCampaignApproved == _FALSE,
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Already approved"
            );

            // cut to disincentivize repeated malicious bidding
            // eg. buyers who keep bidding unwanted campaigns
            uint256 pricePending = s.pricePending;
            uint256 zestyShare = pricePending.mul(_zestyCut).div(10000);
            uint256 validatorShare = pricePending.mul(_validatorCut).div(10000); 
            uint256 returnToBuyer = pricePending.sub(validatorShare).sub(zestyShare);
            s.pricePending = 0;

            require(
                _txToken.transfer(_buyerCampaigns[s.buyerCampaign].buyer, returnToBuyer),
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );
            require(
                _txToken.transfer(owner(), zestyShare),
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );
            require(
                _txToken.transfer(_validator, validatorShare),
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );

            s.buyerCampaign = 0;

            emit SellerAuctionBuyerCampaignReject(_sellerAuctionId[i]);
        }
    }

    function contractSetHashlockBatch(
        uint256[] memory _contractId, 
        bytes32[] memory _hashlock, 
        uint32[] memory _totalShares
    ) external {
        require(
            _contractId.length == _hashlock.length &&
            _hashlock.length == _totalShares.length,
            "ZestyMarket_ERC20_V2::contractSetHashlockBatch: Array length not equal"
        );
        require(
            msg.sender == _validator, 
            "ZestyMarket_ERC20_V2::contractSetHashlockBatch: Not validator"
        );

        for (uint i=0; i < _contractId.length; i++) {
            Contract storage c = _contracts[_contractId[i]];

            require(
                c.sellerAuctionId != 0 || c.buyerCampaignId != 0,
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Invalid contract"
            );
            require(
                c.withdrawn == _FALSE && c.refunded == _FALSE, 
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Already withdrawn or refunded"
            );

            c.hashlock = _hashlock[i];
            delete c.shares;  // clear old shares if any
            c.totalShares = _totalShares[i];

            emit ContractSetHashlock(
                _contractId[i], 
                c.hashlock,
                c.totalShares
            );
        }
    }

    function contractSetShare(uint256 _contractId, string memory _share) external {
        require(msg.sender == _validator, "ZestyMarket_ERC20_V2::contractSetShare: Not validator");
        Contract storage c = _contracts[_contractId];

        require(
            c.sellerAuctionId != 0 || c.buyerCampaignId != 0,
            "ZestyMarket_ERC20_V2::contractWithdrawBatch: Invalid contract"
        );
        require(
            c.hashlock != 0x0, 
            "ZestyMarket_ERC20_V2::contractSetShare: Hashlock has not been set"
        );

        // does not check for validity of share
        // the checking will be done offchain through publicly verifiable secret sharing
        c.shares.push(_share);

        emit ContractSetShare(
            _contractId, 
            _share
        );
    }

    function contractWithdrawBatch(uint256[] memory _contractId, bytes32[] memory _preimage) external nonReentrant {
        require(
            _contractId.length == _preimage.length,
            "ZestyMarket_ERC20_V2::contractWithdrawBach: Array length not equal"
        );
        for(uint i=0; i < _contractId.length; i++) {
            Contract storage c = _contracts[_contractId[i]];
            SellerAuction storage s = _sellerAuctions[c.sellerAuctionId];
            BuyerCampaign storage b = _buyerCampaigns[c.buyerCampaignId];

            require(
                s.seller == msg.sender || isOperator(s.seller, msg.sender), 
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Not seller or operator"
            );
            require(
                c.sellerAuctionId != 0 || c.buyerCampaignId != 0,
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Invalid contract"
            );
            require(
                block.timestamp > c.contractTimeEnd, 
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Contract has not ended"
            );
            require(
                c.withdrawn == _FALSE && c.refunded == _FALSE, 
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Already withdrawn or refunded"
            );
            require(
                c.shares.length != 0
                && c.totalShares != 0
                && c.shares.length >= c.totalShares.mul(_minAvailabilityThreshold).div(10000), 
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Availability threshold not reached"
            );
            require(
                c.hashlock == keccak256(abi.encodePacked(_preimage[i])), 
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Incorrect preimage"
            );

            c.withdrawn = _TRUE;
            
            // cut for validators and zesty dao
            uint256 zestyShare = c.contractValue.mul(_zestyCut).div(10000);
            uint256 validatorShare = c.contractValue.mul(_validatorCut).div(10000); 
            uint256 returnToSeller = c.contractValue.sub(validatorShare).sub(zestyShare);

            require(
                _txToken.transfer(s.seller, returnToSeller),
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );
            require(
                _txToken.transfer(owner(), zestyShare),
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );
            require(
                _txToken.transfer(_validator, validatorShare),
                "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
            );

            SellerNFTSetting storage se = _sellerNFTSettings[s.tokenId];
            se.inProgressCount = se.inProgressCount.sub(1);

            uint256 reward = _rewardsRate.mul(c.contractValue);

            // give out rewards if there are enough rewards
            if (_rewardsBalance >= reward.mul(6)) {
                require(
                    _rewardsToken.transfer(s.seller, reward),
                    "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
                );
                require(
                    _rewardsToken.transfer(b.buyer, reward),
                    "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
                );
                require(
                    _rewardsToken.transfer(_validator, reward.mul(3)),
                    "ZestyMarket_ERC20_V2::sellerAuctionRejectBatch: Transfer of ERC20 failed"
                );
                _zestyNFT.lockZestyToken(s.tokenId, reward);
                _rewardsBalance = _rewardsBalance.sub(reward.mul(3));
            }


            emit SellerNFTUpdate(
                se.tokenId,
                se.autoApprove,
                se.inProgressCount
            );

            emit ContractWithdraw(_contractId[i], reward, reward, reward);
        }
    }

    function contractRefundBatch(uint256[] memory _contractId) external nonReentrant {
        for(uint i=0; i < _contractId.length; i++) {
            Contract storage c = _contracts[_contractId[i]];
            SellerAuction storage s = _sellerAuctions[c.sellerAuctionId];
            BuyerCampaign storage b = _buyerCampaigns[c.buyerCampaignId];

            require(
                b.buyer == msg.sender || isOperator(b.buyer, msg.sender), 
                "ZestyMarket_ERC20_V2::contractRefundBatch: Not seller or operator"
            );
            require(
                c.sellerAuctionId != 0 || c.buyerCampaignId != 0,
                "ZestyMarket_ERC20_V2::contractRefundBatch: Invalid contract"
            );
            require(
                block.timestamp > c.contractTimeEnd + _gracePeriod, 
                "ZestyMarket_ERC20_V2::contractRefundBatch: Contract has not ended"
            );
            require(
                c.withdrawn == _FALSE && c.refunded == _FALSE, 
                "ZestyMarket_ERC20_V2::contractRefundBatch: Already withdrawn or refunded"
            );

            c.refunded = _TRUE;

            require(
                _txToken.transfer(b.buyer, c.contractValue),
                "ZestyMarket_ERC20_V2::contractWithdrawBatch: Transfer of ERC20 failed"
            );

            SellerNFTSetting storage se = _sellerNFTSettings[s.tokenId];
            se.inProgressCount = se.inProgressCount.sub(1);

            emit SellerNFTUpdate(
                se.tokenId,
                se.autoApprove,
                se.inProgressCount
            );

            emit ContractRefund(_contractId[i]);
        }
    }

    function notifyRewardAmount(uint256 reward) external override onlyRewardsDistributor {
        _rewardsBalance = _rewardsBalance.add(reward);
        emit RewardAdded(reward);
    }
}
