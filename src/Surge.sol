// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import "../../dependencies/openzeppelin/contracts/SafeMath.sol";
import "../../dependencies/openzeppelin/contracts/Ownable.sol";
import "../../dependencies/openzeppelin/contracts/ERC20Capped.sol";
import "../../dependencies/governance/TreasuryOwnable.sol";

contract SURGE is Ownable, ERC20Capped, TreasuryOwnable {
    using SafeMath for uint256;

    uint256 public immutable mintLockTime; // no more mint amount change
    // can mint between start time and expiration time
    uint256 public immutable mintStartTime;
    uint256 public immutable mintExpirationTime;

    mapping(address => uint256) private _mints;

    event Mint(
        address indexed minter,
        address indexed onBehalfOf,
        uint256 amount
    );

    constructor(
        uint256 mintLockTime_,
        uint256 mintStartTime_,
        uint256 mintExpirationTime_,
        address treasury_
    )
        Ownable()
        TreasuryOwnable(treasury_)
        ERC20("SURGE", "SURGE")
        ERC20Capped(333333333000000000000000000)
    {
        require(
            mintLockTime_ < mintStartTime_,
            "SURGE: Mint should not start before mint amounts are locked"
        );
        require(
            mintStartTime_ < mintExpirationTime_,
            "SURGE: Mint Should not expire before it starts"
        );
        mintLockTime = mintLockTime_;
        mintStartTime = mintStartTime_;
        mintExpirationTime = mintExpirationTime_;

        _mints[treasury_] = 333333333000000000000000000;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(
            block.timestamp >= mintStartTime,
            "SURGE: Cannot transfer before mint starts"
        );
        super._transfer(sender, recipient, amount);
    }

    function transferTreasury(
        address newTreasury
    ) external override onlyTreasury {
        require(
            newTreasury != address(0),
            "TreasuryOwnable: new treasury is the zero address"
        );
        // transfer mintable amount
        uint256 mintAmount = _mints[treasury()];
        if (mintAmount > 0) {
            delete _mints[treasury()];
            _mints[newTreasury] = _mints[newTreasury].add(mintAmount);
        }
        _transferTreasury(newTreasury);
    }

    function mintOf(address account) public view returns (uint256) {
        return _mints[account];
    }

    function mint() external returns (bool) {
        require(
            block.timestamp >= mintStartTime,
            "SURGE: Cannot mint before mint started"
        );
        require(
            block.timestamp < mintExpirationTime,
            "SURGE: Cannot mint after mint expired"
        );

        address sender = _msgSender();
        uint256 mintAmount = _mints[sender];
        require(mintAmount > 0, "SURGE: nothing to mint");

        delete _mints[sender];
        _mint(sender, mintAmount);
        emit Mint(sender, sender, mintAmount);
        return true;
    }

    function mintByTreasury(
        address account
    ) external onlyTreasury returns (bool) {
        require(
            block.timestamp >= mintExpirationTime,
            "SURGE: No expired token for treasury to mint before mint expired"
        );

        uint256 mintAmount = _mints[account];
        require(mintAmount > 0, "SURGE: nothing to mint");

        delete _mints[account];
        _mint(treasury(), mintAmount);
        emit Mint(treasury(), account, mintAmount);
        return true;
    }

    function setMint(address account, uint256 amount) external onlyOwner {
        require(
            block.timestamp < mintLockTime,
            "SURGE: Cannot set mint amount after mint locked"
        );
        require(
            account != treasury(),
            "SURGE: Should not adjust mint amount for treasury"
        );
        uint256 currentAmount = _mints[account];
        // adjust treasury's mintable amount
        _mints[treasury()] = _mints[treasury()].add(currentAmount).sub(
            amount,
            "SURGE: amount exceeds maximum allowance"
        );
        // record new amount
        if (amount == 0) {
            delete _mints[account];
        } else {
            _mints[account] = amount;
        }
    }

    function setMints(
        address[] memory accounts,
        uint256[] memory amounts
    ) external onlyOwner {
        require(
            block.timestamp < mintLockTime,
            "SURGE: Cannot set mint amount after mint locked"
        );
        require(accounts.length == amounts.length, "SURGE: input mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 amount = amounts[i];
            require(
                account != treasury(),
                "SURGE: Should not adjust mint amount for treasury"
            );
            uint256 currentAmount = _mints[account];
            // adjust treasury's mintable amount
            _mints[treasury()] = _mints[treasury()].add(currentAmount).sub(
                amount,
                "SURGE: amount exceeds maximum allowance"
            );
            // record new amount
            if (amount == 0) {
                delete _mints[account];
            } else {
                _mints[account] = amount;
            }
        }
    }

    function addMint(address account, uint256 amount) external onlyOwner {
        require(
            block.timestamp < mintLockTime,
            "SURGE: Cannot add mint amount after mint locked"
        );
        require(amount > 0, "SURGE: Meaningless to add zero amount");
        require(
            account != treasury(),
            "SURGE: Should not adjust mint amount for treasury"
        );

        // adjust treasury's mintable amount
        _mints[treasury()] = _mints[treasury()].sub(
            amount,
            "SURGE: amount exceeds maximum allowance"
        );
        // record new amount
        _mints[account] = _mints[account].add(amount);
    }
}
