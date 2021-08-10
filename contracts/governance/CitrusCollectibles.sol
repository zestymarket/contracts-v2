// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../utils/ERC1155.sol";
import "../utils/Ownable.sol";
import "../utils/Pausable.sol";


contract CitrusCollectibles is ERC1155, Ownable, Pausable {
    constructor (address owner_, string memory uri_) 
        Ownable(owner_)
        ERC1155(uri_)
    {
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(
        address account, 
        uint256 id, 
        uint256 amounts, 
        bytes memory data
    ) 
        onlyOwner 
        public 
    {
        _mint(account, id, amounts, data);
    }

    function mintBatch(
        address account, 
        uint256[] memory ids, 
        uint256[] memory amounts, 
        bytes memory data
    ) 
        onlyOwner 
        public 
    {
        _mintBatch(account, ids, amounts, data);
    }

    function burn(
        address account, 
        uint256 id, 
        uint256 amounts
    ) 
        onlyOwner 
        public 
    {
        _burn(account, id, amounts);
    }

    function burnBatch(
        address account, 
        uint256[] memory ids, 
        uint256[] memory amounts
    ) 
        onlyOwner 
        public 
    {
        _burnBatch(account, ids, amounts);
    }

    function setURI(string memory uri) onlyOwner public {
        _setURI(uri);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        require(!paused(), "CitrusCollectibles::_beforeTokenTransfer: Cannot transfer token while paused");
    }
}