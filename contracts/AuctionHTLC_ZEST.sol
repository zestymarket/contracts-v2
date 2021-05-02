// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/GSN/Context.sol";
import "./openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./ZestyNFT.sol";
import "./ZestyToken.sol";


contract AuctionHTLC_ZEST is Context, ERC721Holder {
    using SafeMath for uint256;
    using SafeMath for uint32;

    address private _zestyTokenAddress;
    address private _zestyNFTAddress;
    address private _validator;  // this refers to a single validator node or the pool
    uint256 private _auctionCount = 0;
    uint256 private _contractCount = 0;
    uint32 private _availabilityThreshold = 7000; // 70.00% availability threshold, accept 30.00% byzantine nodes
    uint256 private _burnPerc = 200; // 2.00 % $ZEST burned upon successful transaction
    // TODO
    // uint256 private stakeRedistributionPerc = 400; // 4.00% redistributed to staking and liquidity provider pools
    uint256 private _validatorPerc = 200; // 2.00% redistributed to validators

    ZestyNFT private _zestyNFT;
    ZestyToken private _zestyToken;

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

    struct NFTDeposit {
        address seller;
        uint256 defaultStartingPrice;
        bool allowAdDisplayWithoutApproval;
        bool allowBuyerToCreateAdSlots;
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

    function getZestyTokenAddress() external view returns (address) {
        return _zestyTokenAddress;
    }

    function getZestyNFTAddress() external view returns (address) {
        return _NFTAddress;
    }

    function getValidatorAddress() external view returns (address) {
        return _validator;
    }

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
        uint256 _tokenId,
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
