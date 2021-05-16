// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./openzeppelin/contracts/utils/Context";
import "./ZestyNFT.sol";

/**
 * @title ZestyVault for depositing ZestyNFTs
 * @author Zesty Market
 * @notice Contract for depositing and withdrawing ZestyNFTs
 */
abstract contract ZestyVault is ERC721Holder, Context {
    address private _zestyNFTAddress;
    ZestyNFT private _zestyNFT;
    
    constructor(address zestyNFTAddress_) {
        _zestyNFTAddress = zestyNFTAddress_;
        _zestyNFT = ZestyNFT(zestyNFTAddress_);
    }

    mapping (uint256 => address) private _nftDeposits;

    /*
     * Getter functions
     */

    function getZestyNFTAddress() public virtual view returns (address) {
        return _zestyNFTAddress;
    }

    function getDepositor(uint256 _tokenId) public virtual view returns (address) {
        return _nftDeposits[_tokenId];
    }

    /*
     * NFT Deposit and Withdrawal Functions
     */

    function _depositZestyNFT(uint256 _tokenId) internal virtual {
        require(
            _zestyNFT.getApproved(_tokenId) == address(this),
            "ZestyVault: Contract is not approved to manage token"
        );

        _nftDeposits[_tokenId] = _msgSender();
        _zestyNFT.safeTransferFrom(_msgSender(), address(this), _tokenId);

        emit NewNFTDeposit(
            _tokenId, 
            _msgSender()
        );
    }

    function _withdrawZestyNFT(uint256 _tokenId) internal virtual onlyDepositor(_tokenId) {
        delete _nftDeposits[_tokenId];

        _zestyNFT.safeTransferFrom(address(this), _msgSender(), _tokenId);

        emit NewNFTWithdrawal(
            _tokenId,
            _msgSender()
        );
    }

    modifier onlyDepositor(_tokenId) {
        address d = _nftDeposits[_tokenId];

        require(
            d == _msgSender(),
            "ZestyVault: Cannot withdraw as caller did not deposit the ZestyNFT"
        );
        _;
    }
}