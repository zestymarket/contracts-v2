pragma solidity ^0.7.6;

import "../../contracts/interfaces/IERC721Receiver.sol";

contract DummyERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        return IERC721Receiver(0).onERC721Received.selector;
    }
}