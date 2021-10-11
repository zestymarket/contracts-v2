// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./ZestyVault.sol";
import "../interface/IZestyMarket_ERC20_V1_1.sol";
import "../interface/IERC20.sol";
import "../utils/ReentrancyGuard.sol";

// Zesty commissions contract todo
contract ZestyCommissions_ERC20_V1_1 is ZestyVault {
    IZestyMarket_ERC20_V1_1 public immutable _zestyMarket;
    IERC20 public immutable _txToken;

    constructor(
        address zestyNFT_, 
        address zestyMarket_,
        address txToken_,
    ) 
        ZestyVault(zestyNFT_)
    {
        _zestyMarket = IZestyMarket_ERC20_v1_1(zestyMarket_);
        _txToken = IERC20(txToken_);
    }

    struct Share {
        uint256 blockNumber; 
        uint256 share;
    }

    // token id to totalShares
    mapping (uint256 => uint256) public _totalShares;
    // token id to address to shares
    mapping (uint256 => mapping(address => Share[]) public _shares;
    // token id to block num where contractwithdrawn to sum
    mapping (uint256 => mapping(uint256 => uint256)) public _sums;

    function sellerNFTDeposit(
        uint256 _tokenId, 
        uint8 _autoApprove
    ) 
        public 
        nonReentrant 
    {
        _depositZestyNFT(_tokenId);
        _zestyMarket.sellerNFTDeposit(_tokenId, _autoApprove);
    }

    function sellerNFTWithdraw(uint256 _tokenId) public nonReentrant {
        _zestyMarket.sellerNFTWithdraw(_tokenId);
        _withdrawZestyNFT(_tokenId);
    }

    function sellerNFTUpdate(
        uint256 _tokenId, 
        uint8 _autoApprove
    ) 
        public
        onlyDepositorOrOperator(_tokenId) 
    {
        _zestyMarket.sellerNFTUpdate(_tokenId, _autoApprove);
    }

    function sellerAuctionCreateBatch(
        uint256 _tokenId,
        uint256[] memory _auctionTimeStart,
        uint256[] memory _auctionTimeEnd,
        uint256[] memory _contractTimeStart,
        uint256[] memory _contractTimeEnd,
        uint256[] memory _priceStart
    ) 
        public 
        onlyDepositorOrOperator(_tokenId)
    {
        _zestyMarket.sellerAuctionCreateBatch(
            _tokenId,
            _auctionTimeStart,
            _auctionTimeEnd,
            _contractTimeStart,
            _contractTimeEnd,
            _priceStart
        );
    }

    function sellerAuctionApproveBatch(
        uint256[] memory _sellerAuctionId
    )
        external
        nonReentrant
    {
        _zestyMarket.sellerAuctionApproveBatch(_sellerAuctionId);
    }

    function sellerAuctionRejectBatch(
        uint256[] memory _sellerAuctionId
    )
        external
        nonReentrant
    {
        _zestyMarket.sellerAuctionRejectBatch(_sellerAuctionId);
    }

    function contractWithdrawBatch(
        uint256[] memory _contractId
    )
        external
        nonReentrant
    {
        _zestyMarket.contractWithdrawBatch(_contractId);
        // TODO get block number and append erc20 to balances.
    }

    function withdraw(
        uint256 _tokenId, 
        uint256 startBlock, 
        uint256 endBlock
    ) public {
        // TODO
    }
}

