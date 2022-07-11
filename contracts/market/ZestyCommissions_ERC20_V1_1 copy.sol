// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./ZestyVault_V2.sol";
import "../interfaces/IZestyMarket_ERC20_V1_1.sol";
import "../interfaces/IERC20.sol";
import "../utils/ReentrancyGuard.sol";
import "../utils/ERC1155.sol";

contract ZestyCommissions_ERC20_V1_1 is ZestyVault_V2, ERC1155, ReentrancyGuard {
    IZestyMarket_ERC20_V1_1 public immutable _zestyMarket;
    IERC20 public immutable _txToken;

    constructor(
        address txToken_,
        address zestyNFT_, 
        address zestyMarket_
    ) 
        ZestyVault_V2(zestyNFT_)
        ERC1155("")
    {
        _zestyMarket = IZestyMarket_ERC20_V1_1(zestyMarket_);
        _txToken = IERC20(txToken_);
    }

    struct Share {
        uint256 blockNumber; 
        uint256 share;
    }

    // deposit id to value
    mapping (uint256 => uint256) public _value;
    // deposit id to totalShares
    mapping (uint256 => uint256) public _totalShares;
    // deposit id to address to shares
    mapping (uint256 => mapping(address => Share[])) public _shares;
    // deposit id to block num where contractwithdrawn to sum
    mapping (uint256 => mapping(uint256 => uint256)) public _sums;

    function uri(uint256 depositId) external view override returns (string memory) {
        // get tokenId from deposit
        return _zestyNFT.tokenURI(getTokenId(depositId));
    }

    function sellerNFTDeposit(
        uint256 _tokenId, 
        uint256 shares,
        uint256 buybackPerShare,
        uint8 _autoApprove
    ) 
        public 
        nonReentrant 
        returns (uint256 depositId)
    {
        uint256 depositId = _depositZestyNFT(_tokenId);
        _zestyNFT.approve(address(_zestyMarket), _tokenId);
        _zestyMarket.sellerNFTDeposit(_tokenId, _autoApprove);
        _mint(msg.sender, depositId, shares, "");
        return depositId;
    }

    function sellerNFTWithdraw(uint256 _depositId) public nonReentrant {
        uint256 tokenId = getTokenId(_depositId);
        _zestyMarket.sellerNFTWithdraw(tokenId);
        _withdrawZestyNFT(tokenId);
    }

    function sellerNFTUpdate(
        uint256 _depositId, 
        uint8 _autoApprove
    ) 
        public
        onlyDepositorOrOperator(_depositId) 
    {
        _zestyMarket.sellerNFTUpdate(_depositId, _autoApprove);
    }

    function sellerAuctionCreateBatch(
        uint256 _depositId,
        uint256[] memory _auctionTimeStart,
        uint256[] memory _auctionTimeEnd,
        uint256[] memory _contractTimeStart,
        uint256[] memory _contractTimeEnd,
        uint256[] memory _priceStart
    ) 
        public 
        onlyDepositorOrOperator(_depositId)
    {
        uint256 _tokenId = getTokenId(_depositId);
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
        uint256 _depositId,
        uint256[] memory _sellerAuctionId
    )
        external
        nonReentrant
        onlyDepositorOrOperator(_depositId)
    {
        _zestyMarket.sellerAuctionApproveBatch(_sellerAuctionId);
    }

    function sellerAuctionRejectBatch(
        uint256 _depositId,
        uint256[] memory _sellerAuctionId
    )
        external
        nonReentrant
        onlyDepositorOrOperator(_depositId)
    {
        _zestyMarket.sellerAuctionRejectBatch(_sellerAuctionId);
    }

    function contractWithdrawBatch(
        uint256 _depositId,
        uint256[] memory _contractId
    )
        external
        nonReentrant
        onlyDepositorOrOperator(_depositId)
    {
        _zestyMarket.contractWithdrawBatch(_contractId);
        // TODO get block number and append erc20 to balances.
    }

    function withdraw(
        uint256 _depositId, 
        uint256 startBlock, 
        uint256 endBlock
    ) public {
        // TODO
    }
}

