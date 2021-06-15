// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";
import "./utils/SafeMath.sol";
import "./utils/ReentrancyGuard.sol";

// Owner is the multisig contract
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256; 

    address private _zestyTokenAddress;
    IERC20 private _zestyToken;

    constructor (address owner_, address zestyTokenAddress_) Ownable(owner_) {
        _zestyTokenAddress = zestyTokenAddress_;
        _zestyToken = IERC20(zestyTokenAddress_);
    }

    struct Vault {
        uint256 startTime;
        uint256 amount;
        uint256 amountClaimed;
        uint256 vestingDuration; // time is in addition to startTime
        uint256 vestingCliff;    // time is in addition to startTime
    }
    mapping (address => Vault) private _vaults;

    event VaultNew(address recipient, uint256 startTime, uint256 amount, uint256 vestingDuration, uint256 vestingCliff);
    event VaultClaim(address recipient, uint256 amountClaimed);
    event VaultCancel(address recipient, uint256 amountClaimed, uint256 amountReturned);


    function getZestyTokenAddress() public view returns (address) {
        return _zestyTokenAddress; 
    }

    function getVault(address _recipient) public view returns (
        uint256 startTime,
        uint256 amount,
        uint256 amountClaimed,
        uint256 vestingDuration,
        uint256 vestingCliff
    ) {

        startTime = _vaults[_recipient].startTime;
        amount = _vaults[_recipient].amount;
        amountClaimed = _vaults[_recipient].amountClaimed;
        vestingDuration = _vaults[_recipient].vestingDuration;
        vestingCliff = _vaults[_recipient].vestingCliff;
    }

    function getAmountVested(address _recipient) public view  returns (uint256) {
        Vault storage v = _vaults[_recipient];

        if (block.timestamp < v.startTime) {
            return 0;
        } else if (block.timestamp.sub(v.startTime) < v.vestingCliff) {
            return 0;
        } else if (block.timestamp.sub(v.startTime) >= v.vestingDuration) {
            // recipient receives all the tokens
            return v.amount;
        } else {
            // rate * timeElapsed
            return v.amount.div(v.vestingDuration).mul(block.timestamp.sub(v.startTime));
        }
    }

    function newVault(
        address _recipient,
        uint256 _amount,
        uint256 _vestingDuration,
        uint256 _vestingCliff
    ) 
        public
        onlyOwner 
        nonReentrant
    {
        require(_vaults[_recipient].startTime == 0, "TokenVesting::addVault: Vault already created");
        require(_vestingCliff > 0, "TokenVesting::addVault: Vesting cliff must be greater than 0");
        require(_amount > 0, "TokenVesting::addVault: Vesting amount must be greater than 0");
        require(_vestingDuration > _vestingCliff, "TokenVesting::addVault: Vesting duration must be greater than vesting cliff");

        if(!_zestyToken.transferFrom(owner(), address(this), _amount)) {
            revert("TokenVesting::addVault: Transfer of Zesty Tokens failed, check if sufficient allowance is provided");
        }

        _vaults[_recipient] = Vault({
            startTime: block.timestamp,
            amount: _amount,
            amountClaimed: 0,
            vestingDuration: _vestingDuration,
            vestingCliff: _vestingCliff
        });

        emit VaultNew(_recipient, block.timestamp, _amount, _vestingDuration, _vestingCliff);
    }

    function cancelVault(address _recipient) public onlyOwner nonReentrant {
        require(_vaults[_recipient].startTime != 0, "TokenVesting::cancelVault: Vault does not exist");
        Vault storage v = _vaults[_recipient];

        uint256 amountVested = getAmountVested(_recipient);
        uint256 amountClaimed = amountVested.sub(v.amountClaimed);
        uint256 amountReturned = v.amount.sub(amountVested);

        // return remaining vested tokens to recipient
        if(!_zestyToken.transfer(_recipient, amountClaimed)) {
            revert("TokenVesting::cancelVault: Transfer of Zesty Tokens failed");
        }

        // return remaining tokens to owner
        if(!_zestyToken.transfer(owner(), amountReturned)) {
            revert("TokenVesting::cancelVault: Transfer of Zesty Tokens failed");
        }

        delete _vaults[_recipient];

        emit VaultCancel(_recipient, amountClaimed, amountReturned);
    }

    function claimVault() public nonReentrant {
        require(_vaults[msg.sender].startTime != 0, "TokenVesting::claimVault: Vault does not exist");

        uint256 amountVested = getAmountVested(msg.sender);
        require(amountVested > 0, "TokenVesting::claimVault: No tokens to claim");

        Vault storage v = _vaults[msg.sender];
        uint256 amountClaimed = amountVested.sub(v.amountClaimed);
        require(amountClaimed > 0, "TokenVesting::claimVault: No tokens to claim");

        // update storage
        v.amountClaimed = v.amountClaimed.add(amountClaimed);
        require(v.amountClaimed <= v.amount, "TokenVesting::claimVault: Amount claimed exceeds amount");

        // return remaining vested tokens to recipient
        if(!_zestyToken.transfer(msg.sender, amountClaimed)) {
            revert("TokenVesting::claimVault: Transfer of Zesty Tokens failed");
        }

        emit VaultClaim(msg.sender, amountClaimed);
    }


}