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
    
    constructor (address zestyNFTAddress_) {
        _zestyNFTAddress = zestyNFTAddress_;
        _zestyNFT = ZestyNFT(zestyNFTAddress_);
    }

    /*
     * NFT Deposit Struct and Events
     */

    /**
     * @dev Struct stores information NFTDeposit
     * @param seller Address of entity that deposited the ZestyNFT into the contract
     * @param defaultRates Default cost in $ZEST per unix second for a declared adslot
     * @param displayWithoutApproval Flag to indicate whether adslot declared require approvals before display
     * @param buyerCanCreateAuction Flag to indicate whether buyers can declare adslots without seller's permission
     * @param zestyTokenValue Amount of $ZEST accrued in the NFT, $ZEST is earned upon successful AuctionHTLC
     */
    event NewNFTDeposit(
        uint256 indexed tokenId,
        address indexed depositor
    );
    event NewNFTWithdrawal(
        uint256 indexed tokenId
    );

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

    function _withdrawZestyNFT(uint256 _tokenId) internal virtual {
        address d = _nftDeposits[_tokenId];

        require(
            d == _msgSender(),
            "ZestyVault: Cannot withdraw as caller did not deposit the ZestyNFT"
        );

        delete _nftDeposits[_tokenId];

        _zestyNFT.safeTransferFrom(address(this), _msgSender(), _tokenId);

        emit NewNFTWithdrawal(
            _tokenId,
            _msgSender()
        );
    }
}