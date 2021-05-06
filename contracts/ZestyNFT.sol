// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./openzeppelin/contracts/GSN/Context.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";

contract ZestyNFT is ERC721 { 
    using SafeMath for uint256;
    uint256 private _tokenCount = 0;

    constructor() ERC721("Zesty Market NFT", "ZESTNFT") {
    }

    event Mint(
        uint256 indexed id,
        address indexed publisher,
        uint256 timeCreated,
        string uri,
        uint256 timestamp
    );
    
    event Burn(
        uint256 indexed id,
        uint256 timestamp
    );

    event ModifyToken (
        uint256 indexed id,
        address indexed publisher,
        uint256 timeCreated,
        string uri,
        uint256 timestamp
    );

    struct tokenData {
        address publisher;
        uint256 timeCreated;
    }

    mapping (uint256 => tokenData) private _tokenData;

    function mint(string memory _uri) public {
        // Checks
        uint256 _timeNow = block.timestamp;

        // mint token
        _safeMint(_msgSender(), _tokenCount);

        // set uri
        _setTokenURI(_tokenCount, _uri);

        _tokenData[_tokenCount] = tokenData(
            _msgSender(),
            _timeNow
        );

        emit Mint(
            _tokenCount,
            _msgSender(),
            _timeNow,
            _uri,
            block.timestamp
        );

        _tokenCount = _tokenCount.add(1);
    }
    
    function burn(uint256 _tokenId) public {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ZestyNFT: Caller is not owner nor approved");
        
        delete _tokenData[_tokenId];
        
        _burn(_tokenId);

        emit Burn(
            _tokenId,
            block.timestamp
        );        
    }

    function getTokenData(uint256 tokenId) public view returns (
        address publisher,
        uint256 timeCreated,
        string memory uri
    ) {
        require(_exists(tokenId), "Token does not exist");
        tokenData storage a = _tokenData[tokenId];
        string memory _uri = tokenURI(tokenId);

        return (
            a.publisher,
            a.timeCreated,
            _uri
        );
    }

    function setTokenURI(uint256 _tokenId, string memory _uri) public {
        require(_exists(_tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "Caller is not owner or approved");

        tokenData storage a = _tokenData[_tokenId];

        _setTokenURI(_tokenId, _uri);

        emit ModifyToken(
            _tokenId,
            a.publisher,
            a.timeCreated,
            _uri,
            block.timestamp
        );
    }
}