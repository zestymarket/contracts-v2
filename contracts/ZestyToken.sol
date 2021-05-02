// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

// Import OpenZeppelin Contract
import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "./ERC20PauseBurnCap.sol";

// This ERC-20 contract mints the specified amount of tokens to the contract creator.
contract ZestyToken is ERC20PauseBurnCap, Ownable {
    uint256 public constant maxCap = (10 ** 8) * (10 ** 18);
    uint256 public constant initialMint = (10 ** 6) * (10 ** 18);

    constructor() 
        ERC20("Zesty Market Token", "ZEST") 
        ERC20PauseBurnCap(maxCap)
    {
        _mint(msg.sender, initialMint);
    }
}
