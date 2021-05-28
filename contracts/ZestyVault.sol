// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./openzeppelin/contracts/utils/Context.sol";
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
    mapping (address => address) private _nftDepositOperators;

    event DepositZestyNFT(uint256 indexed tokenId, address depositor);
    event WithdrawZestyNFT(uint256 indexed tokenId);
    event AuthorizeOperator(address indexed depositor, address operator);
    event RevokeOperator(address indexed depositor, address operator);

    /*
     * Getter functions
     */

    function getZestyNFTAddress() public virtual view returns (address) {
        return _zestyNFTAddress;
    }

    function getDepositor(uint256 _tokenId) public virtual view returns (address) {
        return _nftDeposits[_tokenId];
    }

    function isDepositor(uint256 _tokenId) public virtual view returns (bool) {
        return _msgSender() == getDepositor(_tokenId);
    }

    function getOperator(address _depositor) public virtual view returns (address) {
        return _nftDepositOperators[_depositor];
    }

    function isOperator(address _depositor, address _operator) public virtual view returns (bool) {
        return _nftDepositOperators[_depositor] == _operator;
    }

    /*
     * Operator functionality
     */
    function authorizeOperator(address _operator) public virtual {
        require(_msgSender() != _operator, "ZestyVault: authorizing self as operator");

        _nftDepositOperators[_msgSender()] = _operator;

        emit AuthorizeOperator(_msgSender(), _operator);
    }

    function revokeOperator(address _operator) public virtual {
        require(_msgSender() != _operator, "ZestyVault: revoking self as operator");

        delete _nftDepositOperators[_msgSender()];

        emit RevokeOperator(_msgSender(), _operator);
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

    modifier onlyOperator(uint256 _tokenId) {
        require(
            getOperator(getDepositor(_tokenId)) == _msgSender(),
            "ZestyVault: Not operator"
        );
        _;
    }

    modifier onlyDepositorOrOperator(uint256 _tokenId) {
        require(
            getDepositor(_tokenId) == _msgSender() 
            || getOperator(getDepositor(_tokenId)) == _msgSender(),
            "ZestyVault: Not depositor or operator"
        );
        _;
    }
}