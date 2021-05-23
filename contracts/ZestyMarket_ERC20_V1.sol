// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ZestyVault.sol";

/**
 * @title Zesty Market V1 using ERC20
 * @author Zesty Market
 * @notice 
 *   Deposit ZestyNFTs for Adslots Auctions and Fulfillment.
 *   Primary use-case of the contract is to experiment on UX flow and value transfer.
 */
contract ZestyMarket_V1 is Ownable, ZestyVault {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _erc20Address;
    uint256 private _buyerOfferCount = 1; // use 0 for empty value
    uint256 private _sellerOfferCount = 1; // use 0 for empty value
    uint256 private _contractCount = 0;
    uint8 private constant _FALSE = 1;
    uint8 private constant _TRUE = 2;

    /** 
     * @dev Constructor sets the various params into private variables declared above
     * @param zestyTokenAddress_ Address where the ERC20 ZestyToken ($ZEST) is deployed
     * @param zestyNFTAddress_ Address where the ERC721 ZestyNFT is deployed
     */
    constructor(
        address erc20Address_,
        address zestyNFTAddress_
    ) 
        ZestyVault(zestyNFTAddress_) 
    {
        _erc20Address = erc20Address_;
    }
    
    struct SellerNFTSetting {
        address seller;
        uint8 requireApproval;
    }
    mapping (uint256 => SellerNFTSetting) private _sellerNFTSettings; 

    event SellerNFTDeposit(uint256 tokenId, address seller, uint8 requireApproval);
    event SellerNFTUpdate(uint256 tokenId, uint8 requireApproval);
    event SellerNFTWithdraw(uint256 tokenId);

    struct BuyerNFTSetting {
        address buyer;
        uint8 requireApproval
    }
    mapping (uint256 => BuyerNFTSetting) private _buyerNFTSettings;

    event BuyerNFTDeposit(uint256 tokenId, address buyer, uint8 requireApproval);
    event BuyerNFTUpdate(uint256 tokenId, uint8 requireApproval);
    event BuyerNFTWithdraw(uint256 tokenId);

    struct SellerAuction {
        uint256 tokenId;
        uint256 auctionTimeStart;
        uint256 auctionTimeEnd;
        uint256 contractTimeStart;
        uint256 contractTimeEnd;
        uint256 priceStart;
        uint256 priceEnd;
        uint256 buyerOffer;
        uint8 buyerOfferApproved;
        uint8 cancelled;
    }

    mapping (uint256 => SellerAuction) private _sellerAuctions; 

    struct BuyerCampaign {
        uint256 tokenId;
        uint256 value;
        uint256[] sellerOfferList;
        uint8 cancelled;
        uint256[] approvedList;
    }
    mapping (uint256 => BuyerCampaign) private _buyerCampaigns;

    struct Contract {
        uint256 auctionId;
        uint8 approved;
        uint8 cancelled;
        uint8 withdrawn
    }

    mapping (uint256 => Contract) private _contracts; 

    event ContractCreate {
        uint256 indexed contractId,
        uint256 auctionId,
        uint8 approved
    }


    function getZestyTokenAddress() public view returns (address) {
        return _zestyTokenAddress;
    }

    function depositZestyNFT(
        uint256 _tokenId,
        uint8 _displayWithoutApproval
    ) public {
        _depositZestyNFT(_tokenId);
        _zestyNFTSettings[_tokenId] = ZestyNFTSetting(_displayWithoutApproval);

        emit ZestyNFTSettingsNew(
            msg.sender,
            _tokenId,
            _displayWithoutApproval
        );
    }

    function withdrawZestyNFT(uint256 _tokenId) public onlyDepositor {
        _withdrawZestyNFT(_tokenId);
        delete _zestyNFTSettings[_tokenId];
        emit ZestyNFTSettingsRemove(_tokenId);
    }

    function updateZestyNFT(
        uint256 _tokenId,
        uint8 _displayWithoutApproval
    ) 
        public
        onlyDepositor
    {
        _zestyNFTSettings[_tokenId] = ZestyNFTSetting(
            _displayWithoutApproval
        );

        emit ZestyNFTSettingsUpdate(
            _tokenId,
            _displayWithoutApproval
        );
    }

    function auctionCreate(
        uint256 _tokenId,
        uint256 _auctionTimeStart,
        uint256 _auctionTimeEnd,
        uint256 _contractTimeStart,
        uint256 _contractTimeEnd,
        uint256 _priceStart
    ) 
        public 
        onlyDepositor
    {
        require(
            _priceStart > 0, 
            "AuctionTLC_ERC20: Starting Price of the Auction must be greater than 0"
        );
        require(
            _auctionTimeStart > block.timestamp,
            "AuctionTLC_ERC20: Starting time of the Auction must be greater than current block timestamp"
        );
        require(
            _auctionTimeEnd > _auctiontimeStart,
            "AuctionTLC_ERC20: Ending time of the Auction must be greater than the starting time of Auction"
        );
        require(
            _contractTimeStart > _auctionTimeStart,
            "AuctionTLC_ERC20: Starting time of the Contract must be greater than the starting time of Auction"
        );
        require(
            _contractTimeEnd > _auctionTimeStart,
            "AuctionTLC_ERC20: Ending time of the Contract must be greater than the starting time of Contract"
        );
        require(
            _contractTimeEnd > _auctionTimeEnd,
            "AuctionTLC_ERC20: Ending time of the Contract must be greater than the ending time of Auction"
        );

        _auctions[_auctionCount] = Auction(
            _tokenId,
            _auctionTimeStart,
            _auctionTimeEnd,
            _contractTimeStart,
            _contractTimeEnd,
            _priceStart,
            0,
            address(0),
            _FALSE,
            _FALSE
        );

        emit AuctionCreate(
            _auctionCount,
            _tokenId,
            _auctionTimeStart,
            _auctionTimeEnd,
            _contractTimeStart,
            _contractTimeEnd,
            _priceStart
        );

        _auctionCount = _auctionCount.add(1);
    }
}
