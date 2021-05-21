// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ZestyVault.sol";

/**
 * @title Auction and Timelock Contract for Adslots using ERC20
 * @author Zesty Market
 * @notice 
 *   Deposit ZestyNFTs for Adslots Auctions and Fulfillment.
 *   Validation isn't provided in this specification.
 *   Seller fraud is possible. 
 *   Primary use-case of the contract is to experiment on UX flow and value transfer.
 */
contract AuctionTLC_ERC20 is Ownable, ZestyVault {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _erc20Address;
    uint256 private _auctionCount = 0;
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
    
    /**
     * @dev ZestyNFTSetting struct stores addtional information out of ZestyVault
     * @param defaultRates Default cost in ERC20 token per second for a declared adslot
     */
    struct ZestyNFTSetting {
        uint8 displayWithoutApproval;
    }

    mapping (uint256 => uint8) private _displayWithoutApproval; 

    event ZestyNFTDeposit(
        uint256 tokenId,
        address depositor,
        uint8 displayWithoutApproval
    );

    event ZestyNFTUpdate(
        uint256 tokenId,
        uint8 displayWithoutApproval
    );

    event ZestyNFTWithdraw(uint256 tokenId);

    /**
     * Auction details
     */
    struct Auction {
        uint256 tokenId;
        uint256 auctionTimeStart;
        uint256 auctionTimeEnd;
        uint256 contractTimeStart;
        uint256 contractTimeEnd;
        uint256 priceStart;
        uint256 priceEnd;
        address buyer;  // default 0x0 if buyer is not 0x0 means the auction is complete
        uint8 cancelled
    }

    mapping (uint256 => Auction) private _auctions; 

    event AuctionCreate(
        uint256 indexed auctionId,
        uint256 tokenId,
        uint256 auctionTimeStart,
        uint256 auctionTimeEnd,
        uint256 contractTimeStart,
        uint256 contractTimeEnd,
        uint256 priceStart
    );
    event AuctionCompleted(uint256 indexed auctionId, uint256 priceEnd, address buyer);
    event AuctionCancelled(uint256 indexed auctionId);

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


    /*
     * Getter functions
     */
    function getZestyTokenAddress() public view returns (address) {
        return _zestyTokenAddress;
    }

    function getZestyNFTSettings(uint256 _tokenId) 
        public 
        view 
        returns (
            uint8 displayWithoutApproval
        ) 
    {
        ZestyNFTSetting storage n = _zestyNFTSettings[_tokenId];
        displayWithoutApproval = n.displayWithoutApproval;
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
