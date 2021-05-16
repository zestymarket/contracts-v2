// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

// Import OpenZeppelin Contract
import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "./openzeppelin/contracts/access/Ownable.sol";

// This ERC-20 contract mints the specified amount of tokens to the contract creator.
contract ZestyToken is ERC20Capped, Ownable {
    uint256 public constant maxCap = (10 ** 8) * (10 ** 18);
    // uint256 public constant initialMint = (10 ** 6) * (10 ** 18);

    constructor() 
        ERC20("Zesty Market Token", "ZESTY") 
        ERC20Capped(maxCap)
    {
        _mint(msg.sender, maxCap);
    }
}
