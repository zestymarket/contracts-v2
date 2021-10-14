// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../utils/Context.sol";
import "../interfaces/IERC721Receiver.sol";
import "../interfaces/IZestyNFT.sol";

/**
 * @title ZestyVault for depositing ZestyNFTs, decouple deposit id from token id
 * @author Zesty Market
 * @notice Contract for depositing and withdrawing ZestyNFTs
 */
abstract contract ZestyVault is Context, IERC721Receiver {
    address private _zestyNFTAddress;
    IZestyNFT internal _zestyNFT;
    uint256 private _depositCount = 0;
    
    constructor(address zestyNFTAddress_) {
        _zestyNFTAddress = zestyNFTAddress_;
        _zestyNFT = IZestyNFT(zestyNFTAddress_);
    }

    mapping (uint256 => uint256) private _depositIdToTokenId;
    mapping (uint256 => address) private _nftDeposits;
    mapping (address => address) private _nftDepositOperators;

    event DepositZestyNFT(uint256 depositId, uint256 indexed tokenId, address depositor);
    event WithdrawZestyNFT(uint256 depositId, uint256 indexed tokenId);
    event AuthorizeOperator(address indexed depositor, address operator);
    event RevokeOperator(address indexed depositor, address operator);

    /*
     * Getter functions
     */

    function getZestyNFTAddress() public virtual view returns (address) {
        return _zestyNFTAddress;
    }

    function getDepositor(uint256 _depositId) public virtual view returns (address) {
        return _nftDeposits[_depositId];
    }

    function isDepositor(uint256 _depositId) public virtual view returns (bool) {
        return _msgSender() == getDepositor(_tokenId);
    }

    function getTokenId(uint256 _depositId) public virtual view returns (bool) {
        return _depositIdToTokenId[_depositId];
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

    function _depositZestyNFT(uint256 _tokenId) internal virtual returns(uint256 depositId) {
        require(
            _zestyNFT.getApproved(_tokenId) == address(this),
            "ZestyVault::_depositZestyNFT: Contract is not approved to manage token"
        );

        _depositCount.add(1);

        _depositIdToTokenId[_depositCount] = _tokenId;
        _nftDeposits[_depositCount] = _msgSender();
        _zestyNFT.safeTransferFrom(_msgSender(), address(this), _tokenId);

        emit DepositZestyNFT(_depositCount, _tokenId, _msgSender());

        return _depositCount;
    }

    function _withdrawZestyNFT(uint256 _tokenId) internal virtual onlyDepositor(_tokenId) {
        delete _nftDeposits[_tokenId];

        _zestyNFT.safeTransferFrom(address(this), _msgSender(), _tokenId);

        emit WithdrawZestyNFT(_tokenId);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }


    modifier onlyDepositor(uint256 _depositId) {
        require(
            getDepositor(_depositId) == _msgSender(),
            "ZestyVault::onlyDepositor: Not depositor"
        );
        _;
    }

    modifier onlyOperator(uint256 _depositId) {
        require(
            getOperator(getDepositor(_depositId)) == _msgSender(),
            "ZestyVault::onlyOperator: Not operator"
        );
        _;
    }

    modifier onlyDepositorOrOperator(uint256 _depositId) {
        require(
            getDepositor(_depositId) == _msgSender() 
            || getOperator(getDepositor(_depositId)) == _msgSender(),
            "ZestyVault::onlyDepositorOrOperator: Not depositor or operator"
        );
        _;
    }
}