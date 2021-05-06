// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/GSN/Context.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StreamGame is Context {
    using SafeMath for uint256;
    address private _dao;
    // USDC Address
    // ETH mainnet: 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
    // Matic sidechain: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
    address private _usdc;
    uint256 private _gameCount = 0;

    constructor(address usdc_) {
        _usdc = usdc_;
    }

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

    modifier tokensTransferrable(address _sender, uint256 _amount) {
        require(_amount > 0, "Cannot send 0 USDC");
        require(
            IERC20(_usdc).allowance(_sender, address(this)) >= _amount,
            "USDC allowance is not sufficient, increase allowance"
        );
        _;
    }

    modifier gameExists(uint256 _gameId) {
        require(_gameStates[_gameId].creator != address(0), "Game does not exist");
        _;
    }

    function getUsdcAddress() public view returns (address) {
        return _usdc;
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

    function start() public returns (uint256) {
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

    function donate(uint256 _gameId, uint256 _val, string memory _message)
        public 
        gameExists(_gameId)
        tokensTransferrable(_msgSender(), _val)
    {
        if (!IERC20(_usdc).transferFrom(_msgSender(), address(this), _val))
            revert("Transfer of usdc to contract failed");

        GameState storage g = _gameStates[_gameId];
        g.totalDonations = g.totalDonations.add(_val);
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
        public 
        gameExists(_gameId)
    {
        GameState storage g = _gameStates[_gameId];
        uint256 withdrawAmt = g.totalDonations;
        g.totalDonations = 0;

        IERC20(_usdc).transfer(g.creator, withdrawAmt);

        emit GameStateWithdraw(
            _gameId,
            g.creator
        );
    }
}