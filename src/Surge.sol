// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.19;

import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "./FiscOwnable.sol";

contract Surge is Ownable, ERC20Capped, FiscOwnable {
    using SafeMath for uint256;

    uint256 public immutable mintLockTime;
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
        address fisc_
    )
        Ownable()
        FiscOwnable(fisc_)
        ERC20("SURGE", "SURGE")
        ERC20Capped(333333333000000000000000000)
    {
        require(
            mintLockTime_ < mintStartTime_,
            "Surge: Mint should not start before the amounts have been locked."
        );
        require(
            mintStartTime_ < mintExpirationTime_,
            "Surge: Mint should not expire before it has started."
        );
        mintLockTime = mintLockTime_;
        mintStartTime = mintStartTime_;
        mintExpirationTime = mintExpirationTime_;

        _mints[fisc_] = 333333333000000000000000000;
    }

    // remove this after testing
    function getMintAmount(address account) external view returns (uint256) {
        return _mints[account];
    }

    function addMint(address account, uint256 amount) external onlyOwner {
        require(
            block.timestamp < mintLockTime,
            "Surge: Cannot add amount after mint has been locked."
        );
        require(amount > 0, "Surge: Cannot add zero to mint.");
        require(
            account != fisc(),
            "Surge: Should not adjust Fisc mint amount."
        );

        // adjust fisc's mintable amount
        _mints[fisc()] = _mints[fisc()].sub(
            amount,
            "Surge: Amount exceeds maximum allowance."
        );
        // record new amount
        _mints[account] = _mints[account].add(amount);
    }

    function setMint(address account, uint256 amount) external onlyOwner {
        require(
            block.timestamp < mintLockTime,
            "Surge: Cannot set mint amount after mint has been locked."
        );
        require(
            account != fisc(),
            "Surge: Should not adjust fisc mint amount."
        );
        uint256 currentAmount = _mints[account];
        // adjust fisc's mintable amount
        _mints[fisc()] = _mints[fisc()].add(currentAmount).sub(
            amount,
            "Surge: Amount exceeds maximum allowance."
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
            "Surge: Cannot set mint amount after mint has been locked."
        );
        require(accounts.length == amounts.length, "Surge: Input mismatch.");
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 amount = amounts[i];
            require(
                account != fisc(),
                "Surge: Should not adjust fisc mint amount."
            );
            uint256 currentAmount = _mints[account];
            // adjust fisc's mintable amount
            _mints[fisc()] = _mints[fisc()].add(currentAmount).sub(
                amount,
                "Surge: Amount exceeds maximum allowance."
            );
            // record new amount
            if (amount == 0) {
                delete _mints[account];
            } else {
                _mints[account] = amount;
            }
        }
    }

    function mintOf(address account) public view returns (uint256) {
        return _mints[account];
    }

    function mint() external returns (bool) {
        require(
            block.timestamp >= mintStartTime,
            "Surge: Cannot mint before the mint has started."
        );
        require(
            block.timestamp < mintExpirationTime,
            "Surge: Cannot mint after the mint has expired."
        );

        address sender = _msgSender();
        uint256 mintAmount = _mints[sender];
        require(mintAmount > 0, "Surge: Nothing to mint.");

        delete _mints[sender];
        _mint(sender, mintAmount);
        emit Mint(sender, sender, mintAmount);
        return true;
    }

    function mintFromFisc(address account) external onlyFisc returns (bool) {
        require(
            block.timestamp >= mintExpirationTime,
            "Surge: Mint has expired."
        );

        uint256 mintAmount = _mints[account];
        require(mintAmount > 0, "Surge: Nothing to mint.");

        delete _mints[account];
        _mint(fisc(), mintAmount);
        emit Mint(fisc(), account, mintAmount);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        require(
            block.timestamp >= mintStartTime,
            "Surge: Cannot transfer before the mint has started."
        );
        super._transfer(sender, recipient, amount);
    }

    function transferFisc(address newFisc) external override onlyFisc {
        require(
            newFisc != address(0),
            "Fisc: Fisc cannot be the zero address."
        );
        // transfer mintable amount
        uint256 mintAmount = _mints[fisc()];
        if (mintAmount > 0) {
            delete _mints[fisc()];
            _mints[newFisc] = _mints[newFisc].add(mintAmount);
        }
        _transferFisc(newFisc);
    }
}
