// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./openzeppelin/contracts/utils/Context.sol";
import "./openzeppelin/contracts/utils/EnumerableSet.sol";
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
    // mapping (address => mapping (uint256 => mapping (address => bool))) _nftDepositOperators;

    event DepositZestyNFT(uint256 indexed tokenId, address depositor);
    event WithdrawZestyNFT(uint256 indexed tokenId);
    // event AuthorizeOperator(uint256 indexed tokenId, address operator, address depositor);
    // event RevokeOperator(uint256 indexed tokenId, address operator, address depositor);

    /*
     * Getter functions
     */

    function getZestyNFTAddress() public virtual view returns (address) {
        return _zestyNFTAddress;
    }

    function getDepositor(uint256 _tokenId) public virtual view returns (address) {
        return _nftDeposits[_tokenId];
    }

    // function isOperatorFor(
    //     uint256 _depositor, 
    //     uint256 _tokenId, 
    //     address _operator
    // ) 
    //     public 
    //     virtual 
    //     view 
    //     returns (bool) 
    // {
    //     return _nftDepositOperators[_depositor][_tokenId][_operator];
    // }

    /*
     * Operator functionality
     */
    // function authorizeOperator(uint256 _tokenId, address _operator) public virtual override onlyDepositor(_tokenId) {
    //     require(_msgSender() != _operator, "ZestyVault: authorizing self as operator");

    //     _nftDepositOperators[_msgSender()][_tokenId][operator] = true;

    //     emit AuthorizeOperator(_tokenId, operator, _msgSender());
    // }

    // function revokeOperator(address operator) public virtual override onlyDepositor(_tokenId) {
    //     require(operator != _msgSender(), "ZestyVault: revoking self as operator");

    //     delete _nftDepositOperators[_msgSender()][_tokenId][operator];

    //     emit RevokeOperator(_tokenId, operator, _msgSender());
    // }

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

        emit DepositZestyNFT(_tokenId, _msgSender());
    }

    function _withdrawZestyNFT(uint256 _tokenId) internal virtual onlyDepositor(_tokenId) {
        delete _nftDeposits[_tokenId];

        _zestyNFT.safeTransferFrom(address(this), _msgSender(), _tokenId);

        emit WithdrawZestyNFT(_tokenId);
    }

    modifier onlyDepositor(uint256 _tokenId) {
        require(
            getDepositor(_tokenId) == _msgSender(),
            "ZestyVault: Not depositor"
        );
        _;
    }

    // modifier onlyOperator(address _depositor, uint256 _tokenId) {
    //     require(
    //         isOperatorFor(_depositor, _tokenId, _msgSender()),
    //         "ZestyVault: Not operator"
    //     );
    //     _;
    // }
}