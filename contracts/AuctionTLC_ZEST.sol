// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./ZestyToken.sol";
import "./ZestyVault.sol";

/**
 * @title Auction and Timelock Contract for Adslots using $ZEST
 * @author Zesty Market
 * @notice 
 *   Deposit ZestyNFTs for Adslots Auctions and Fulfillment.
 *   Validation isn't provided in this specification.
 */
contract AuctionTLC_ZEST is Ownable, ZestyVault {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _zestyTokenAddress;
    uint256 private _auctionCount = 0;
    uint256 private _contractCount = 0;
    uint256 private _burnPerc = 100;  // 1.00%
    // uint256 private stakeRedistributionPerc = 400; // TODO: 4.00%
    ZestyToken private _zestyToken;


    /** 
     * @dev Constructor sets the various params into private variables declared above
     * @param zestyTokenAddress_ Address where the ERC20 ZestyToken ($ZEST) is deployed
     * @param zestyNFTAddress_ Address where the ERC721 ZestyNFT is deployed
     */
    constructor(
        address zestyTokenAddress_,
        address zestyNFTAddress_
    )
        ZestyVault(zestyNFTAddress_)
    {
        _zestyTokenAddress = zestyTokenAddress_;
        _zestyToken = ZestyToken(zestyTokenAddress_);
    }

    /**
     * @dev ZestyNFTSetting struct stores addtional information out of ZestyVault
     * @param defaultRates Default cost in $ZEST per second for a declared adslot
     * @param displayWithoutApproval Flag to indicate whether adslot declared require approvals before display
     * @param anyoneCanCreateAuction Flag to indicate whether buyers can declare adslots without seller's permission
     * @param zestyTokenValue Amount of $ZEST accrued in the NFT, $ZEST is earned upon successful AuctionHTLC
     */
    struct ZestyNFTSetting {
        uint256 defaultRates;
        bool anyoneCanCreateAuction;
        bool displayWithoutApproval;
        uint256 zestyTokenValue;
    }

    mapping (uint256 => NFTSetting) _zestyNFTSettings; 

    event ZestyNFTSettingsNew(
        uint256 tokenId,
        uint256 defaultRates,
        bool anyoneCanCreateAuction,
        bool displayWithoutApproval,
        uint256 zestyTokenValue
    );

    event ZestyNFTSettingsUpdate(
        uint256 tokenId,
        uint256 defaultRates,
        bool anyoneCanCreateAuction,
        bool displayWithoutApproval,
        uint256 zestyTokenValue
    );

    event ZestyNFTSettingsRemove(uint256 tokenId);

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
            uint256 defaultRates,
            bool anyoneCanCreateAuction,
            bool displayWithoutApproval,
            uint256 zestyTokenValue
        ) 
    {
        ZestyNFTSetting storage n = _zestyNFTSettings[_tokenId];
        defaultRates = n.defaultRates;
        anyoneCanCreateAuction = n.anyoneCanCreateAuction;
        displayWithoutApproval = n.displayWithoutApproval;
        zestyTokenValue = n.zestyTokenValue;
    }

    function depositZestyNFT(
        uint256 _tokenId,
        uint256 _defaultRates,
        bool _anyoneCanCreateAuction,
        bool displayWithoutApproval
    ) public {
        _depositZestyNFT(_tokenId);
        _zestyNFTSettings[_tokenId] = ZestyNFTSetting(
            _defaultRates,
            _anyoneCanCreateAuction,
            _displayWithoutApproval,
            0,
        );

        emit ZestyNFTSettingsNew(
            _tokenId,
            _defaultRates,
            _anyoneCanCreateAuction,
            _displayWithoutApproval,
            0
        );
    }

    function withdrawZestyNFT(uint256 _tokenId) public {
        _withdrawZestyNFT(_tokenId);
        delete _zestyNFTSettings[_tokenId];
        emit ZestyNFTSettingsRemove(_tokenId);
    }

    function updateZestyNFT(
        uint256 _tokenId,
        uint256 _defaultRates,
        bool _anyoneCanCreateAuction,
        bool displayWithoutApproval
    ) public {
        _zestyNFTSettings[_tokenId] = ZestyNFTSetting(
            _defaultRates,
            _anyoneCanCreateAuction,
            _displayWithoutApproval,
            0,
        );

        emit ZestyNFTSettingsUpdate(
            _tokenId,
            _defaultRates,
            _anyoneCanCreateAuction,
            _displayWithoutApproval,
            0
        );
    }
}
