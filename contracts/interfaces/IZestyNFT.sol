// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./IERC721.sol";
import "./IERC721Metadata.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev Required interface of an ZestyNFT compliant contract.
 */
interface IZestyNFT is IERC721, IERC721Metadata, IERC721Enumerable {
    function getTokenData(uint256 tokenId) 
    external
    view 
    returns (
        address creator,
        uint256 timeCreated,
        uint256 zestyTokenValue,
        string memory uri
    ); 
    function getZestyTokenAddress() external view returns (address);
    function setZestyTokenAddress(address zestyTokenAddress_) external;
    function mint(string memory _uri) external;
    function burn(uint256 _tokenId) external;
    function setTokenURI(uint256 _tokenId, string memory uri) external;
    function lockZestyToken(uint256 _tokenId, uint256 _value) external;
}