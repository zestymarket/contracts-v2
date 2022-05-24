// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../utils/ReentrancyGuard.sol";
import "../utils/EnumerableSet.sol";
import "../utils/PaymentSplitter.sol";
import "../interfaces/IZestyMarket_ERC20_V1_1.sol";
import "../interfaces/IZestyNFT.sol";

contract ZestyRevenueShareWrapper is ReentrancyGuard {
  using EnumerableSet for EnumerableSet.AddressSet;

  IZestyMarket_ERC20_V1_1 public zestyMarketAddress;
  PaymentSplitter public paymentSplitter;
  mapping(uint256 => address) public owners;

  constructor(address zestyMarketAddress_, address payable paymentSplitter_) {
    zestyMarketAddress = IZestyMarket_ERC20_V1_1(zestyMarketAddress_);
    paymentSplitter = PaymentSplitter(paymentSplitter_);
  }

  function sellerNFTDeposit(uint256 _tokenId, uint8 _autoApprove, address[] calldata recipients_, uint256[] calldata shares_) external nonReentrant {
    require(recipients_.length <= 20, "Too many recipients");
    require(recipients_.length == shares_.length, "Length mismatch");
    IZestyNFT _zestyNFT = IZestyNFT(zestyMarketAddress.getZestyNFTAddress());
    require(
      _zestyNFT.ownerOf(_tokenId) == msg.sender &&
      _zestyNFT.getApproved(_tokenId) == address(this),
      "Contract is not approved to manage token"
    );

    owners[_tokenId] = msg.sender;
    paymentSplitter.addPayees(recipients_, shares_);

    _zestyNFT.safeTransferFrom(msg.sender, address(this), _tokenId);
    _zestyNFT.approve(address(zestyMarketAddress), _tokenId);
    zestyMarketAddress.sellerNFTDeposit(_tokenId, _autoApprove);
  }

  function sellerNFTWithdraw(uint256 _tokenId) external onlyDepositOwner(_tokenId) {
    zestyMarketAddress.sellerNFTWithdraw(_tokenId);
    IZestyNFT _zestyNFT = IZestyNFT(zestyMarketAddress.getZestyNFTAddress());
    _zestyNFT.safeTransferFrom(address(this), msg.sender, _tokenId);
    owners[_tokenId] = address(0);
    // clear recipients TO-do
    // uint256 length = _recipients[_tokenId].length();
    // for(uint256 i = 0; i < length; i ++) {
    //   _recipients[_tokenId].remove(_recipients[_tokenId].at(0));
    // }
  }

  // To-do
  function addRecipient(uint256 _tokenId, address newRecipient) external onlyDepositOwner(_tokenId) returns(bool success) {
    // require(_recipients[_tokenId].length() < 20, "Too many recipients");
    // success = _recipients[_tokenId].add(newRecipient);
  }

  // To-do
  function removeRecipient(uint256 _tokenId, address oldRecipient) external onlyDepositOwner(_tokenId) returns(bool success) {
    // success = _recipients[_tokenId].remove(oldRecipient);
  }

  modifier onlyDepositOwner(uint256 _tokenId) {
    require(msg.sender == owners[_tokenId], "Not owner");
    _;
  }
}
