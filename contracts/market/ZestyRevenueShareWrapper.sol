// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../utils/ReentrancyGuard.sol";
import "../utils/EnumerableSet.sol";
import "../interfaces/IZestyMarket_ERC20_V1_1.sol";
import "../interfaces/IZestyNFT.sol";
import "../interfaces/ISplitMain.sol";

contract ZestyRevenueShareWrapper is ReentrancyGuard {
  using EnumerableSet for EnumerableSet.AddressSet;

  IZestyMarket_ERC20_V1_1 public zestyMarketAddress;
  ISplitMain public constant splitMain = ISplitMain(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE);
  address public supportedERC20Token;
  mapping(uint256 => address) public owners;
  mapping(uint256 => address) public splits;

  constructor(address zestyMarketAddress_, address supportedERC20Token_) {
    zestyMarketAddress = IZestyMarket_ERC20_V1_1(zestyMarketAddress_);
    supportedERC20Token = supportedERC20Token_;
  }

  // Total sum of shares should be equal to 1e6
  function sellerNFTDeposit(uint256 _tokenId, uint8 _autoApprove, address[] calldata recipients_, uint32[] calldata shares_) external nonReentrant {
    require(recipients_.length <= 20, "Too many recipients");
    require(recipients_.length == shares_.length, "Length mismatch");
    IZestyNFT _zestyNFT = IZestyNFT(zestyMarketAddress.getZestyNFTAddress());
    require(
      _zestyNFT.ownerOf(_tokenId) == msg.sender &&
      _zestyNFT.getApproved(_tokenId) == address(this),
      "Contract is not approved to manage token"
    );

    owners[_tokenId] = msg.sender;

    _zestyNFT.safeTransferFrom(msg.sender, address(this), _tokenId);
    _zestyNFT.approve(address(zestyMarketAddress), _tokenId);
    zestyMarketAddress.sellerNFTDeposit(_tokenId, _autoApprove);

    if(splits[_tokenId] != address(0)) {
      // Already existing
      splitMain.updateSplit(splits[_tokenId], recipients_, shares_, 0);
    } else {
      splits[_tokenId] = splitMain.createSplit(recipients_, shares_, 0, address(this));
    }
  }

  function sellerNFTWithdraw(uint256 _tokenId) external onlyDepositOwner(_tokenId) {
    zestyMarketAddress.sellerNFTWithdraw(_tokenId);
    IZestyNFT _zestyNFT = IZestyNFT(zestyMarketAddress.getZestyNFTAddress());
    _zestyNFT.safeTransferFrom(address(this), msg.sender, _tokenId);
    owners[_tokenId] = address(0);
  }

  function distributeETH(uint256 _tokenId, address[] calldata recipients_, uint32[] calldata shares_) external onlyDepositOwner(_tokenId) {
    require(splits[_tokenId] != address(0), "Split not existing");
    splitMain.distributeETH(splits[_tokenId], recipients_, shares_, 0, address(this));
  }

  function distributeERC20(uint256 _tokenId, address[] calldata recipients_, uint32[] calldata shares_) external onlyDepositOwner(_tokenId) {
    require(splits[_tokenId] != address(0), "Split not existing");
    splitMain.distributeERC20(splits[_tokenId], supportedERC20Token, recipients_, shares_, 0, address(this));
  }

  function updateSplit(uint256 _tokenId,  address[] calldata recipients_, uint32[] calldata shares_) external onlyDepositOwner(_tokenId) {
    require(splits[_tokenId] != address(0), "Split not existing");
    splitMain.updateSplit(splits[_tokenId], recipients_, shares_, 0);
  }

  modifier onlyDepositOwner(uint256 _tokenId) {
    require(msg.sender == owners[_tokenId], "Not owner");
    _;
  }
}
