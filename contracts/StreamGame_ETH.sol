// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/GSN/Context.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";

contract StreamGame_ETH is Context {
    using SafeMath for uint256;
    address private _erc20Address;
    uint256 private _gameCount = 0;

    constructor() {}

    struct GameState {
        address creator;
        address currentDonor;
        uint256 totalDonations;
        string currentMessage;
    }

    mapping (uint256 => GameState) _gameStates;

    event GameStateNew (
        uint256 indexed gameId,
        address indexed creator,
        uint256 timestamp
    );

    event GameStateUpdate(
        uint256 indexed gameId,
        address indexed creator,
        address indexed currentDonor,
        string currentMessage,
        uint256 totalDonations,
        uint256 timestamp
    );

    event GameStateWithdraw(
        uint256 indexed gameId,
        address indexed creator
    );

    modifier gameExists(uint256 _gameId) {
        require(_gameStates[_gameId].creator != address(0), "Game does not exist");
        _;
    }

    function getGameState(uint256 _gameId) public view returns (
        address creator,
        address currentDonor,
        uint256 totalDonations,
        string memory currentMessage
    ) {
        GameState storage g = _gameStates[_gameId];

        creator = g.creator;
        currentDonor = g.currentDonor;
        totalDonations = g.totalDonations;
        currentMessage = g.currentMessage;
    }

    function start() external returns (uint256) {
        _gameCount = _gameCount.add(1);

        _gameStates[_gameCount] = GameState(
            _msgSender(),   // creator
            address(0),     // donor 
            0,              // current donations
            ""             // current message
        );

        emit GameStateNew(
            _gameCount,
            _msgSender(),
            block.timestamp
        );

        return _gameCount;
    }

    function donate(uint256 _gameId, string memory _message)
        external 
        payable
        gameExists(_gameId)
    {
        require(msg.value > 0, "Value needs to be greater than 0");

        GameState storage g = _gameStates[_gameId];
        g.totalDonations = g.totalDonations.add(msg.value);
        g.currentDonor = _msgSender();
        g.currentMessage = _message;

        emit GameStateUpdate(
            _gameId,
            g.creator,
            _msgSender(),
            g.currentMessage,
            g.totalDonations,
            block.timestamp
        );
    }

    function withdraw(uint256 _gameId) 
        external 
        gameExists(_gameId)
    {
        GameState storage g = _gameStates[_gameId];
        require(g.totalDonations > 0, "No funds to withdraw");

        uint256 withdrawAmt = g.totalDonations;
        g.totalDonations = 0;

        (bool sent,) = g.creator.call{value: withdrawAmt}("");
        require(sent, "Failed to withdraw ether");

        emit GameStateWithdraw(
            _gameId,
            g.creator
        );
    }
}