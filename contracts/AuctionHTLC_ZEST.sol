// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/GSN/Context.sol";
import "./openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./ZestyNFT.sol";
import "./ZestyToken.sol";

/**
 * @title AuctionHTLC for transacting with $ZEST
 * @author Zesty Market
 * @notice Contract for depositing ZestyNFTs into the contract segment timeslots for AuctionHTLCs
 */
contract AuctionHTLC_ZEST is Context, Ownable, ERC721Holder {
    /**
     *  @notice Libraries used in the contract
     */
    using SafeMath for uint256;
    using SafeMath for uint32;

    /**
     * @dev Variables used in the contract
     * @param _zestyTokenAddress Address where the ERC20 ZestyToken ($ZEST) is deployed
     * @param _zestyNFTAddress Address where the ERC721 ZestyNFT is deployed
     * @param _validator Address of validator (this could be an account or contract)
     * @param _auctionCount Count of the number of auctions on chain, used to track id
     * @param _contractCount Count of the number of contracts on chain, used to track id
     * @param _availabilityThreshold Minimum percentage of shares required to withdraw funds from contract
     * @param _burnPerc Percentage of desposited ERC20 ZestyToken ($ZEST) burned after a contract ends (cancellation, withdrawal, refund)
     * @param _profitSharePerc Percentage of deposited ERC20 ZestyToken redistributed to the DAO after successful withdrawal
     * @param _validatorPerc Percentage of deposited ERC20 ZestyToken ($ZEST) transferred to validator address after successful withdrawal
     * @param _zestyToken ERC20 ZestyToken contract instance
     * @param _zestyNFT ERC721 ZestyNFT contract instance
     */
    address private _zestyTokenAddress;
    address private _zestyNFTAddress;
    address private _validator;
    uint256 private _auctionCount = 0;
    uint256 private _contractCount = 0;
    uint32 private _availabilityThreshold = 7000;  // 70.00%
    uint256 private _burnPerc = 100;  // 1.00%
    // uint256 private stakeRedistributionPerc = 400; // TODO: 4.00%
    ZestyToken private _zestyToken;
    ZestyNFT private _zestyNFT;


    /** 
     * @dev Constructor sets the various params into private variables declared above
     * @param _zestyTokenAddress Address where the ERC20 ZestyToken ($ZEST) is deployed
     * @param _zestyNFTAddress Address where the ERC721 ZestyNFT is deployed
     * @param _validator Address of validator (this could be an account or contract)
     */
    constructor(
        address zestyTokenAddress_, 
        address zestyNFTAddress_,
        address validator_
    ) {
        _zestyTokenAddress = zestyTokenAddress_;
        _zestyNFTAddress = zestyNFTAddress_;
        _validator = validator_;
        _zestyNFT = ZestyNFT(zestyNFTAddress_);
        _zestyToken = ZestyToken(zestyTokenAddress_);
    }

    /*
     * NFT Deposit Struct and Events
     */

    /**
     * @dev Struct stores information NFTDeposit
     * @param seller Address of entity that deposited the ZestyNFT into the contract
     * @param defaultRates Default cost in $ZEST per unix second for a declared adslot
     * @param displayWithoutApproval Flag to indicate whether adslot declared require approvals before display
     * @param buyerCanCreateSlots Flag to indicate whether buyers can declare adslots without seller's permission
     * @param zestyTokenValue Amount of $ZEST accrued in the NFT, $ZEST is earned upon successful AuctionHTLC
     */
    struct NFTDeposit {
        address seller;
        uint256 defaultRates;
        bool displayWithoutApproval;
        bool buyerCanCreateSlots;
        uint256 zestyTokenValue;
    }
    event NewNFTDeposit(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 defaultStartingPrice,
        bool allowAdDisplayWithoutApproval,
        bool allowBuyerToCreateAdSlots,
        uint256 timestamp
    );
    event NewNFTWithdrawal(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 timestamp
    );

    mapping (uint256 => NFTDeposit) private _nftDeposits; // uint256 is the tokenId

    /*
     * Getter functions
     */
    function getZestyTokenAddress() external view returns (address) {
        return _zestyTokenAddress;
    }

    function getZestyNFTAddress() external view returns (address) {
        return _NFTAddress;
    }

    function getValidatorAddress() external view returns (address) {
        return _validator;
    }

    /*
     * NFT Deposit and Withdrawal Functions
     */

    function depositZestyNFT(
        uint256 _tokenId,
        uint256 _defaultStartingPrice,
        bool _allowAdDisplayWithoutApproval,
        bool _allowBuyerToCreateAdSlots
    ) public {
        require(
            _zestyNFT.getApproved(_tokenId == address(this)),
            "AuctionHTLC_ZEST: Contract is not approved to manage token"
        );

        _nftDeposits[_tokenId] = NFTDeposit(
            _msgSender(),
            _defaultStartingPrice,
            _allowAdDisplayWithoutApproval,
            _allowBuyerToCreateAdSlots
        );

        _zestyNFT.safeTransferFrom(_msgSender(), address(this), _tokenId);

        emit NewNFTDeposit(
            _tokenId,
            _msgSender(),
            _defaultStartingPrice,
            _allowAdDisplayWithoutApproval,
            _allowBuyerToCreateAdSlots,
            block.timestamp
        );
    }

    function withdrawZestyNFT(
        uint256 _tokenId
    ) public {
        NFTDeposit storage n = _nftDeposits[_tokenId];

        require(
            n.seller == _msgSender(),
            "AuctionHTLC_ZEST: Not seller"
        );

        delete _nftDeposits[_tokenId];

        _zestyNFT.safeTransferFrom(address(this), _msgSender(), _tokenId);

        emit NewNFTWithdrawal(
            _tokenId,
            _msgSender(),
            block.timestamp
        );
    }

}
