// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "./utils/ERC721.sol";
import "./interfaces/IERC20.sol";
import "./utils/SafeMath.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Ownable.sol";

contract ZestyNFT is ERC721, Ownable, ReentrancyGuard { 
    using SafeMath for uint256;
    uint256 private _tokenCount = 0;
    address private _zestyTokenAddress;
    IERC20 private _zestyToken;

    constructor(address owner_, address zestyTokenAddress_) 
        Ownable(owner_)
        ERC721("Zesty Market NFT", "ZESTYNFT") 
    {
        _zestyTokenAddress = zestyTokenAddress_;
        _zestyToken = IERC20(zestyTokenAddress_);
    }

    event Mint(
        uint256 indexed id,
        address indexed creator,
        uint256 timeCreated,
        string uri
    );
    
    event Burn(
        uint256 indexed id,
        uint256 zestyTokenValue
    );

    event LockZestyToken (
        uint256 indexed id,
        uint256 zestyTokenValue
    );

    event ModifyToken (
        uint256 indexed id,
        string uri
    );

    event NewZestyTokenAddress(address zestyTokenAddress);

    struct TokenData {
        address creator;
        uint256 timeCreated;
        uint256 zestyTokenValue;
    }

    mapping (uint256 => TokenData) private _tokenData;

    function getTokenData(uint256 tokenId) 
        public
        view 
        returns (
            address creator,
            uint256 timeCreated,
            uint256 zestyTokenValue,
            string memory uri
        ) 
    {
        require(_exists(tokenId), "ZestyNFT::getTokenData: Token does not exist");
        TokenData storage a = _tokenData[tokenId];
        string memory _uri = tokenURI(tokenId);

        creator = a.creator;
        timeCreated = a.timeCreated; 
        zestyTokenValue = a.zestyTokenValue;
        uri = _uri;
    }

    function getZestyTokenAddress() public view returns (address) {
        return _zestyTokenAddress;
    }

    // TODO: Burn the owner address by sending to 0x once the zestyTokenAddress has been set
    // This is to prevent a change in zestyTokenAddress once the ZestyNFT contract accrues value
    // This will cause a problem with the ERC20 balances denoted by zestyTokenValue
    function setZestyTokenAddress(address zestyTokenAddress_) public onlyOwner {
        _zestyTokenAddress = zestyTokenAddress_;
        _zestyToken = IERC20(zestyTokenAddress_);

        emit NewZestyTokenAddress(zestyTokenAddress_);
    }


    function mint(string memory _uri) public {
        // Checks
        uint256 _timeNow = block.timestamp;

        // mint token
        _safeMint(_msgSender(), _tokenCount);

        // set uri
        _setTokenURI(_tokenCount, _uri);

        _tokenData[_tokenCount] = TokenData(
            _msgSender(),
            _timeNow,
            0
        );

        emit Mint(
            _tokenCount,
            _msgSender(),
            _timeNow,
            _uri
        );

        _tokenCount = _tokenCount.add(1);
    }

    function lockZestyToken(uint256 _tokenId, uint256 _value) public nonReentrant {
        require(
            _zestyTokenAddress != address(0),
            "ZestyNFT::lockZestyToken: Unable to lock ZestyTokens as zestyToken is not ready"
        );

        if (!_zestyToken.transferFrom(_msgSender(), address(this), _value))
            revert("ZestyNFT::lockZestyToken: Transfer of ZestyTokens to ZestyNFT failed");

        TokenData storage a = _tokenData[_tokenId];
        a.zestyTokenValue = a.zestyTokenValue.add(_value);

        emit LockZestyToken(
            _tokenId,
            a.zestyTokenValue
        );
    }
    
    function burn(uint256 _tokenId) public nonReentrant {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId), 
            "ZestyNFT::burn: Caller is not owner nor approved"
        );
        TokenData storage a = _tokenData[_tokenId];
        uint256 zestyTokenValue = a.zestyTokenValue;
        delete _tokenData[_tokenId];

        if(_zestyTokenAddress != address(0)) {
            if (!_zestyToken.transfer(_msgSender(), zestyTokenValue))
                revert("ZestyNFT::burn: Transfer of ZestyTokens from ZestyNFT to caller failed");
        }

        _burn(_tokenId);

        emit Burn(
            _tokenId,
            a.zestyTokenValue
        );        
    }

    function setTokenURI(uint256 _tokenId, string memory _uri) public {
        require(_exists(_tokenId), "ZestyNFT::setTokenURI: Token does not exist");
        require(ownerOf(_tokenId) == _msgSender(), "ZestyNFT::setTokenURI: Caller not owner");

        TokenData storage a = _tokenData[_tokenId];
        require(a.creator == _msgSender(), "ZestyNFT::setTokenURI: Caller is not creator of token");

        _setTokenURI(_tokenId, _uri);

        emit ModifyToken(
            _tokenId,
            _uri
        );
    }
}