// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./ZestyNFT.sol";
import "./ZestyToken.sol";


contract AuctionHTLC is Context, ERC721Holder {
    using SafeMath for uint256;
    using SafeMath for uint32;
    address private _tokenAddress;
    address private _NFTAddress;
    address private _validator;  // single validator implementation
    uint256 private _auctionCount = 0;
    uint256 private _contractCount = 0;
    uint32 private _availabilityThreshold = 8000; // 80.00% availability threshold
    uint256 private _burnPerc = 200; // 2.00 % burned upon successful transaction
    // TODO
    // uint256 private stakeRedistributionPerc = 400; // 4.00% redistributed to staking and liquidity provider pools
    uint256 private _validatorPerc = 200; // 2.00% redistributed to validators

    ZestyNFT private _zestyNFT;
    ZestyToken private _zestyToken;

    constructor(
        address tokenAddress_, 
        address NFTAddress_,
        address validator_
    ) {
        _tokenAddress = tokenAddress_;
        _NFTAddress = NFTAddress_;
        _validator = validator_;
        _zestyNFT = ZestyNFT(_NFTAddress);
        _zestyToken = ZestyToken(_tokenAddress);
    }

    // Auction Section 
    enum AuctionState {
        START,
        SUCCESS,
        EXPIRE,
        CANCEL
    }

    event AuctionStart(
        uint256 indexed auctionId,
        address indexed publisher,
        string tokenGroup,
        uint256 tokenId,
        uint256 startPrice,
        uint256 timeStart,
        uint256 timeEnd,
        uint256 timeEndToken,
        uint256 timestamp
    );
    event AuctionCancel(
        uint256 indexed auctionId,
        address indexed publisher,
        uint256 timestamp
    );
    event AuctionExpire(
        uint256 indexed auctionId,
        address indexed publisher,
        uint256 timestamp
    );
    event AuctionSuccess(
        uint256 indexed auctionId,
        address indexed publisher,
        address indexed advertiser,
        uint256 bidPrice,
        uint256 timestamp
    );

    struct Auction {
        address publisher;
        address advertiser;
        string tokenGroup;
        uint256 tokenId;
        uint256 startPrice;
        uint256 timeStart;
        uint256 timeEnd;
        uint256 timeEndToken;
        uint256 bidPrice;
        AuctionState state;
    }

    mapping (uint256 => Auction) private _auctions;

    // Hash timelock contract section
    enum ContractState {
        START,
        WITHDRAW,
        REFUND,
        CANCEL
    }
    event ContractStart(
        uint256 indexed contractId,
        address indexed publisher, 
        address indexed advertiser,
        string tokenGroup,
        uint256 tokenId,
        uint256 amount,
        uint256 timelock,
        uint256 timestamp
    );
    event ContractSetHashlock(
        uint256 indexed contractId,
        bytes32 hashlock,
        uint32 totalShares,
        uint256 timestamp
    );
    event ContractSetShare(
        uint256 indexed contractId,
        string share,
        uint256 timestamp
    );
    event ContractCancel(
        uint256 indexed contractId,
        uint256 timestamp
    );
    event ContractWithdraw(
        uint256 indexed contractId,
        uint256 timestamp
    );
    event ContractRefund(
        uint256 indexed contractId,
        uint256 timestamp
    );

    struct Contract {
        address publisher;
        address advertiser;
        string tokenGroup;
        uint256 tokenId;
        uint256 amount;
        bytes32 hashlock;
        uint256 timelock;
        string[] shares;
        uint32 totalShares;
        ContractState state;
    }

    mapping (uint256 => Contract) private _contracts;


    function getTokenAddress() external view returns (address) {
        return _tokenAddress;
    }

    function getNFTAddress() external view returns (address) {
        return _NFTAddress;
    }

    function getValidator() external view returns (address) {
        return _validator;
    }

    function getAuction(uint256 _auctionId) public view returns (
        address,
        address,
        string memory,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        AuctionState
    ) {
        Auction storage a = _auctions[_auctionId];

        return (
            a.publisher,
            a.advertiser,
            a.tokenGroup,
            a.tokenId,
            a.startPrice,
            a.timeStart,
            a.timeEnd,
            a.timeEndToken,
            a.bidPrice,
            a.state
        );
    }

    function getContract(uint256 _contractId) public view returns (
        address,
        address,
        string memory,
        uint256,
        uint256,
        bytes32,
        uint256,
        string[] memory,
        uint32,
        ContractState
    ) {
        Contract storage c = _contracts[_contractId];

        return (
            c.publisher,
            c.advertiser,
            c.tokenGroup,
            c.tokenId,
            c.amount,
            c.hashlock,
            c.timelock,
            c.shares,
            c.totalShares,
            c.state
        );
    }

    function auctionStart(
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _timeEnd
    ) public {
        require(
            _zestyNFT.getApproved(_tokenId) == address(this),
            "Contract is not approved to manage the token"
        );
        require(
            _startPrice > 0,
            "Starting Price of the Dutch auction must be greater than 0"
        );
        require(
            _timeEnd > block.timestamp,
            "Ending time of the Dutch auction must be in the future"
        );

        string memory _tokenGroup;
        address _publisher;
        uint256 _timeCreated;
        uint256 _timeStartToken;
        uint256 _timeEndToken;
        string memory _uri;

        (_tokenGroup,
         _publisher,
         _timeCreated,
         _timeStartToken,
         _timeEndToken,
         _uri) = _zestyNFT.getTokenData(_tokenId);

        require(
            _timeEndToken > _timeEnd,
            "Ending time of auction is later than expiry of token"
        );

        _zestyNFT.safeTransferFrom(_msgSender(), address(this), _tokenId);

        _auctions[_auctionCount] = Auction(
            _publisher,
            address(0),
            _tokenGroup,
            _tokenId,
            _startPrice,
            block.timestamp,
            _timeEnd,
            _timeEndToken,
            uint256(0),
            AuctionState.START
         );

        emit AuctionStart(
            _auctionCount,
            _publisher,
            _tokenGroup,
            _tokenId,
            _startPrice,
            block.timestamp,
            _timeEnd,
            _timeEndToken,
            block.timestamp
        );
        _auctionCount = _auctionCount.add(1);
    }

    function auctionCancel(uint256 _auctionId) public {
        Auction storage a = _auctions[_auctionId];

        require(a.state == AuctionState.START, "Auction is not in START state");
        require(_msgSender() == a.publisher, "Not publisher");

        if (block.timestamp < a.timeEnd) {
            a.state = AuctionState.CANCEL;
            emit AuctionCancel(
                _auctionId,
                a.publisher,
                block.timestamp
            );
        } else {
            a.state = AuctionState.EXPIRE;
            emit AuctionExpire(
                _auctionId,
                a.publisher,
                block.timestamp
            );
        }
        _zestyNFT.safeTransferFrom(address(this), _msgSender(), a.tokenId);
    }

    function auctionBid(uint256 _auctionId) public {
        Auction storage a = _auctions[_auctionId];
        uint256 timeNow = block.timestamp;

        require(a.state == AuctionState.START, "Auction is not available for bidding");
        require(a.publisher != _msgSender(), "Cannot bid on own auction");
        require(timeNow < a.timeEnd, "Auction has expired");

        uint256 timePassed = timeNow.sub(a.timeStart);
        uint256 timeTotal = a.timeEndToken.sub(a.timeStart);

        // rescale the values to accomodate decimals
        uint256 reStartPrice = a.startPrice.mul(100000);
        uint256 gradient = reStartPrice.div(timeTotal);

        uint256 bidPrice = reStartPrice.sub(gradient.mul(timePassed)).div(100000);

        if(!_zestyToken.transferFrom(_msgSender(), address(this), bidPrice)) {
            revert("Transfer $ZEST failed, check if sufficient allowance is provided");
        }

        a.state = AuctionState.SUCCESS;
        a.bidPrice = bidPrice;
        a.advertiser = _msgSender();

        emit AuctionSuccess(
            _auctionId,
            a.publisher,
            a.advertiser,
            a.bidPrice,
            timeNow
        );

        // create contract
        Contract storage c = _contracts[_contractCount];
        c.publisher = a.publisher;
        c.advertiser = a.advertiser;
        c.tokenGroup = a.tokenGroup;
        c.tokenId = a.tokenId;
        c.amount = a.bidPrice;
        c.timelock = a.timeEndToken.add(86400); // add 24 hrs to the end of ad slot
        c.state = ContractState.START;

        emit ContractStart(
            _contractCount,
            c.publisher,
            c.advertiser,
            c.tokenGroup,
            c.tokenId,
            c.amount,
            c.timelock,
            timeNow
        );

        _contractCount = _contractCount.add(1);
    }

    function contractSetTokenURI(uint256 _contractId, string memory _uri) public { 
        Contract storage c = _contracts[_contractId];
        require(c.publisher != address(0), "Contract does not exist");
        require(c.state == ContractState.START, "Contract already ended");
        require(c.advertiser == _msgSender(), "Not advertiser");
        _zestyNFT.setTokenURI(c.tokenId, _uri);
    }

    function contractSetHashlock(
        uint256 _contractId, 
        bytes32 _hashlock, 
        uint32 _totalShares
    ) public {
        require(_msgSender() == _validator, "Not validator");

        Contract storage c = _contracts[_contractId];

        require(c.publisher != address(0), "Contract does not exist");
        require(c.hashlock == 0x0, "Hashlock already set");
        require(c.state == ContractState.START, "Contract already ended");

        c.hashlock = _hashlock;
        c.totalShares = _totalShares;

        emit ContractSetHashlock(
            _contractId, 
            c.hashlock,
            c.totalShares,
            block.timestamp
        );
    }

    function contractSetShare(uint256 _contractId, string memory _share) public {
        require(_msgSender() == _validator, "Not validator");
        Contract storage c = _contracts[_contractId];

        require(c.publisher != address(0), "Contract does not exist");
        require(c.hashlock != 0x0, "Hashlock has not been set");
        require(c.state == ContractState.START, "Contract already ended");

        // does not check for validity of share
        // the checking will be done offchain through publicly veriable secret sharing
        c.shares.push(_share);

        emit ContractSetShare(
            _contractId, 
            _share,
            block.timestamp
        );
    }

    function contractRefund(uint256 _contractId) public {
        Contract storage c = _contracts[_contractId];
        require(c.publisher != address(0), "Contract does not exist");
        require(_msgSender() == c.advertiser, "Not advertiser");
        // check for shares length and totalShares, 
        // if it's 0 that means the validator malfunctioned
        // else prevent refund because availability threshold is reached 
        // % of byzantine validators < availability threshold. 
        // Otherwise this refund could be invalid as the shares could be withheld 
        // by a byzantine node
        if (c.shares.length != 0 && c.totalShares != 0) {
            require(
                c.shares.length < c.totalShares.mul(_availabilityThreshold).div(10000), 
                "Availability threshold reached"
            );
        }
        require(c.state == ContractState.START, "Contract already ended");
        // We still keep a timelock in the event the advertiser is still delivering the adslot
        // but have yet to receive sufficient share
        require(c.timelock < block.timestamp, "Timelock not yet passed"); 

        c.state = ContractState.REFUND;
        // refund advertiser
        _zestyToken.transfer(c.advertiser, c.amount);

        // return NFT to publisher
        _zestyNFT.safeTransferFrom(address(this), c.publisher, c.tokenId);

        emit ContractRefund(
            _contractId,
            block.timestamp
        );
    }

    function contractWithdraw(uint256 _contractId, bytes32 _preimage) public {
        Contract storage c = _contracts[_contractId];
        require(c.publisher != address(0), "Contract does not exist");
        require(_msgSender() == c.publisher, "Not publisher");
        require(
            c.shares.length >= c.totalShares.mul(_availabilityThreshold).div(10000), 
            "Availability threshold not reached"
        );
        require(c.state == ContractState.START, "Contract already ended");
        // We still use a hashlock as a final check because length of shares
        // is insufficient to demonstrate that the advertisement has been served
        // possibility of malicious nodes in multi public validator system
        require(
            c.hashlock == keccak256(abi.encodePacked(_preimage)), 
            "Hashlock does not match"
        );

        c.state = ContractState.WITHDRAW;
    
        uint256 burnAmount = c.amount.mul(_burnPerc).div(10000);
        uint256 valAmount = c.amount.mul(_validatorPerc).div(10000);
        uint256 remaining = c.amount.sub(burnAmount).sub(valAmount);

        // burn tokens
        _zestyToken.burn(burnAmount);

        // give some to validators
        _zestyToken.transfer(_validator, valAmount);

        // give rest to publisher
        _zestyToken.transfer(c.publisher, remaining);

        // Give advertiser NFT for collection
        _zestyNFT.safeTransferFrom(address(this), c.advertiser, c.tokenId);

        emit ContractRefund(
            _contractId,
            block.timestamp
        );
    }

    function contractCancel(uint256 _contractId) public {
        Contract storage c = _contracts[_contractId];
        require(c.publisher != address(0), "Contract does not exist");
        require(c.state == ContractState.START, "Contract already ended");
        require(c.publisher == _msgSender(), "Not publisher");

        c.state = ContractState.CANCEL;

        // Return the advertiser money
        _zestyToken.transfer(c.advertiser, c.amount);

        // Return the publisher the NFT
        _zestyNFT.safeTransferFrom(address(this), c.publisher, c.tokenId);

        emit ContractCancel(
            _contractId,
            block.timestamp
        );
    }
}
