// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.4;

import {ISplitMain} from './ISplitMain.sol';
import {ERC20} from './ERC20.sol';
import {SafeTransferLib} from './SafeTransferLib.sol';
import "../../interfaces/IZestyMarket_ERC20_V1_1.sol";
import "../../interfaces/IZestyNFT.sol";
/**
 * ERRORS
 */

/// @notice Unauthorized sender
error Unauthorized();

/**
 * @title SplitWallet
 * @author 0xSplits <will@0xSplits.xyz>
 * @notice The implementation logic for `SplitProxy`.
 * @dev `SplitProxy` handles `receive()` itself to avoid the gas cost with `DELEGATECALL`.
 */
contract SplitWallet {
  using SafeTransferLib for address;
  using SafeTransferLib for ERC20;

  /**
   * EVENTS
   */

  /** @notice emitted after each successful ETH transfer to proxy
   *  @param split Address of the split that received ETH
   *  @param amount Amount of ETH received
   */
  event ReceiveETH(address indexed split, uint256 amount);

  /**
   * STORAGE
   */

  /**
   * STORAGE - CONSTANTS & IMMUTABLES
   */

  /// @notice address of SplitMain for split distributions & EOA/SC withdrawals
  ISplitMain public immutable splitMain;

  /// @notice tokenId of the NFT
  uint256 private tokenId;

  /// @notice zesty market address
  IZestyMarket_ERC20_V1_1 public zestyMarketAddress;

  /// @notice recipient addresses
  address[] private accounts;
  
  /// @notice percentage shares
  uint32[] private percentAllocations;

  /**
   * MODIFIERS
   */

  /// @notice Reverts if the sender isn't SplitMain
  modifier onlySplitMain() {
    if (msg.sender != address(splitMain)) revert Unauthorized();
    _;
  }

  /**
   * CONSTRUCTOR
   */

  constructor() {
    splitMain = ISplitMain(msg.sender);
  }

  /**
   * FUNCTIONS - PUBLIC & EXTERNAL
   */

  function init(uint256 tokenId_, address zestyMarketAddress_, address[] memory accounts_, uint32[] memory percentAllocations_) external onlySplitMain() {
    tokenId = tokenId_;
    zestyMarketAddress = IZestyMarket_ERC20_V1_1(zestyMarketAddress_);
    for(uint256 i = 0; i < accounts_.length; i ++) {
      accounts.push(accounts_[i]);
      percentAllocations.push(percentAllocations_[i]);
    }
  }

  function sellerNFTDeposit(uint8 _autoApprove) external onlySplitMain() {
    IZestyNFT _zestyNFT = IZestyNFT(zestyMarketAddress.getZestyNFTAddress());

    // NFT was already transferred so no need to check ownership here
    _zestyNFT.approve(address(zestyMarketAddress), tokenId);
    zestyMarketAddress.sellerNFTDeposit(tokenId, _autoApprove);
  }

  function authorizeOperator(address _operator) external onlySplitMain() {
    zestyMarketAddress.authorizeOperator(_operator);
  }

  function sellerAuctionCreateBatch (
    uint256[] memory _auctionTimeStart,
    uint256[] memory _auctionTimeEnd,
    uint256[] memory _contractTimeStart,
    uint256[] memory _contractTimeEnd,
    uint256[] memory _priceStart
  ) external onlySplitMain() {
    zestyMarketAddress.sellerAuctionCreateBatch(tokenId, _auctionTimeStart, _auctionTimeEnd, _contractTimeStart, _contractTimeEnd, _priceStart);
  }

  /** @notice Sends amount `amount` of ETH in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @param amount Amount to send
   */
  function sendETHToMain(uint256 amount) external payable onlySplitMain() {
    address(splitMain).safeTransferETH(amount);
  }

  /** @notice Sends amount `amount` of ERC20 `token` in proxy to SplitMain
   *  @dev payable reduces gas cost; no vulnerability to accidentally lock
   *  ETH introduced since fn call is restricted to SplitMain
   *  @param token Token to send
   *  @param amount Amount to send
   */
  function sendERC20ToMain(ERC20 token, uint256 amount)
    external
    payable
    onlySplitMain()
  {
    token.safeTransfer(address(splitMain), amount);
  }
}
