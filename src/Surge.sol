// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "./FiscOwnable.sol";

contract Surge is ERC20Capped, Ownable, FiscOwnable {
    using SafeMath for uint256;

    uint256 public immutable mintLock;
    uint256 public immutable mintStart;
    uint256 public immutable mintEnd;

    mapping(address => uint256) private _mints;

    event Mint(address indexed minter, address indexed mintee, uint256 amount);

    constructor(uint256 mintLock_, uint256 mintStart_, uint256 mintEnd_, address fisc_)
        Ownable()
        FiscOwnable(fisc_)
        ERC20("SURGE", "SURGE")
        ERC20Capped(333333333000000000000000000)
    {
        require(mintLock_ < mintStart_, "Surge: Mint should not start before the amounts have been locked.");
        require(mintStart_ < mintEnd_, "Surge: Mint should not expire before it has started.");
        mintLock = mintLock_;
        mintStart = mintStart_;
        mintEnd = mintEnd_;

        _mints[fisc_] = 333333333000000000000000000;
    }

    function mint() external returns (bool) {
        require(block.timestamp >= mintStart, "Surge: Cannot mint before the mint has started.");
        require(block.timestamp < mintEnd, "Surge: Cannot mint after the mint has expired.");

        address sender = _msgSender();
        uint256 mintAmount = _mints[sender];
        require(mintAmount > 0, "Surge: Nothing to mint.");

        delete _mints[sender];
        _mint(sender, mintAmount);
        emit Mint(sender, sender, mintAmount);
        return true;
    }

    function addMint(address account, uint256 amount) external onlyOwner {
        require(block.timestamp < mintLock, "Surge: Cannot add amount after mint has been locked.");
        require(amount > 0, "Surge: Cannot add zero to mint.");
        require(account != Fisc(), "Surge: Should not adjust Fisc mint amount.");

        _mints[Fisc()] = _mints[Fisc()].sub(amount, "Surge: Amount exceeds maximum allowance.");
        _mints[account] = _mints[account].add(amount);
    }

    function setMint(address account, uint256 amount) external onlyOwner {
        require(block.timestamp < mintLock, "Surge: Cannot set mint amount after mint has been locked.");
        require(account != Fisc(), "Surge: Should not adjust fisc mint amount.");

        uint256 currentAmount = _mints[account];

        _mints[Fisc()] = _mints[Fisc()].add(currentAmount).sub(amount, "Surge: Amount exceeds maximum allowance.");

        if (amount == 0) {
            delete _mints[account];
        } else {
            _mints[account] = amount;
        }
    }

    function setMints(address[] memory accounts, uint256[] memory amounts) external onlyOwner {
        require(block.timestamp < mintLock, "Surge: Cannot set mint amount after mint has been locked.");
        require(accounts.length == amounts.length, "Surge: Input mismatch.");

        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            uint256 amount = amounts[i];

            require(account != Fisc(), "Surge: Should not adjust fisc mint amount.");

            uint256 currentAmount = _mints[account];

            _mints[Fisc()] = _mints[Fisc()].add(currentAmount).sub(amount, "Surge: Amount exceeds maximum allowance.");

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

    function mintFromFisc(address account) external onlyFisc returns (bool) {
        require(block.timestamp >= mintEnd, "Surge: Mint has expired.");

        uint256 mintAmount = _mints[account];
        require(mintAmount > 0, "Surge: Nothing to mint.");

        delete _mints[account];
        _mint(Fisc(), mintAmount);
        emit Mint(Fisc(), account, mintAmount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(block.timestamp >= mintStart, "Surge: Cannot transfer before the mint has started.");
        super._transfer(sender, recipient, amount);
    }

    function transferFisc(address newFisc) external override onlyFisc {
        require(newFisc != address(0), "Fisc: Fisc cannot be the zero address.");

        uint256 mintAmount = _mints[Fisc()];

        if (mintAmount > 0) {
            delete _mints[Fisc()];
            _mints[newFisc] = _mints[newFisc].add(mintAmount);
        }
        _transferFisc(newFisc);
    }
}
