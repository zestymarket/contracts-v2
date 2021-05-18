// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./ZestyToken.sol";

contract ZestyNFT is ERC721, Ownable, ReentrancyGuard { 
    using SafeMath for uint256;
    uint256 private _tokenCount = 0;
    address private _zestyTokenAddress;
    ZestyToken private _zestyToken;

    constructor(address zestyTokenAddress_) 
        ERC721("Zesty Market NFT", "ZESTYNFT") 
    {
        _zestyTokenAddress = zestyTokenAddress_;
        _zestyToken = ZestyToken(zestyTokenAddress_);
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
        require(_exists(tokenId), "Token does not exist");
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
        _zestyToken = ZestyToken(zestyTokenAddress_);

        emit NewZestyTokenAddress(zestyTokenAddress_);
    }


    function mint(string memory _uri) public {
        // Checks
        uint256 _timeNow = block.timestamp;

        // mint token
        _safeMint(msg.sender, _tokenCount);

        // set uri
        _setTokenURI(_tokenCount, _uri);

        _tokenData[_tokenCount] = TokenData(
            msg.sender,
            _timeNow,
            0
        );

        emit Mint(
            _tokenCount,
            msg.sender,
            _timeNow,
            _uri
        );

        _tokenCount = _tokenCount.add(1);
    }

    function lockZestyToken(uint256 _tokenId, uint256 _value) public nonReentrant {
        require(
            _zestyTokenAddress != address(0),
            "ZestyNFT: Unable to lock ZestyTokens as zestyToken is not ready"
        );

        if (!_zestyToken.transferFrom(msg.sender, address(this), _value))
            revert("ZestyNFT: Transfer of ZestyTokens to ZestyNFT failed");

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
            "ZestyNFT: Caller is not owner nor approved"
        );

        TokenData storage a = _tokenData[_tokenId];
        
        delete _tokenData[_tokenId];
        
        _burn(_tokenId);

        if (!_zestyToken.transferFrom(address(this), msg.sender, a.zestyTokenValue))
            revert("ZestyNFT: Transfer of ZestyTokens from ZestyNFT to caller failed");

        emit Burn(
            _tokenId,
            a.zestyTokenValue
        );        
    }

    function setTokenURI(uint256 _tokenId, string memory _uri) public {
        require(_exists(_tokenId), "ZestyNFT: Token does not exist");

        TokenData storage a = _tokenData[_tokenId];
        require(a.creator == msg.sender, "ZestyNFT: Caller is not creator of token");

        _setTokenURI(_tokenId, _uri);

        emit ModifyToken(
            _tokenId,
            _uri
        );
    }
}