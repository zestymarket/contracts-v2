// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import "../utils/SafeMath.sol";

contract ZestyDice_ETH {
    using SafeMath for uint256;
    address private _erc20Address;
    uint256 private _gameCount = 0;
    uint256 private _nonce = 0;

    constructor() {}

    struct GameState {
        address creator;
        address currentDonor;
        uint256 totalDonations;
        string currentMessage;
        uint8 currentDiceRoll;
    }

    mapping (uint256 => GameState) _gameStates;

    event GameStateNew (
        uint256 indexed gameId,
        address indexed creator
    );

    event GameStateUpdate(
        uint256 indexed gameId,
        address indexed currentDonor,
        uint256 currentDonation,
        string currentMessage,
        uint256 totalDonations,
        uint8 currentDiceRoll
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
        string memory currentMessage,
        uint8 currentDiceRoll
    ) {
        GameState storage g = _gameStates[_gameId];

        creator = g.creator;
        currentDonor = g.currentDonor;
        totalDonations = g.totalDonations;
        currentMessage = g.currentMessage;
        currentDiceRoll = g.currentDiceRoll;
    }

    function start() external returns (uint256) {
        _gameCount = _gameCount.add(1);

        _gameStates[_gameCount] = GameState(
            msg.sender,   // creator
            address(0),     // donor 
            0,              // total donations
            "",             // current message
            0               // current dice roll
        );

        emit GameStateNew(
            _gameCount,
            msg.sender
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
        g.currentDonor = msg.sender;
        g.currentMessage = _message;
        // pseudorandom number, 
        // decided not to use chainlink VRF
        // randomness is
        g.currentDiceRoll = uint8(uint(keccak256(abi.encodePacked(
            block.difficulty,
            block.timestamp,
            _nonce,
            g.currentDiceRoll
        ))) % 6);

        _nonce = _nonce.add(1);

        emit GameStateUpdate(
            _gameId,
            msg.sender,
            msg.value,
            g.currentMessage,
            g.totalDonations,
            g.currentDiceRoll
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