// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "../lib/openzeppelin-contracts/contracts/utils/Context.sol";

abstract contract FiscOwnable is Context {
    address private _fisc;

    event FiscTransferred(address indexed previousFisc, address indexed newFisc);

    constructor(address fisc_) {
        _fisc = fisc_;
        emit FiscTransferred(address(0), fisc_);
    }

    function Fisc() public view virtual returns (address) {
        return _fisc;
    }

    modifier onlyFisc() {
        require(Fisc() == _msgSender(), "Fisc: Caller must be the Fisc.");
        _;
    }

    function transferFisc(address newFisc) external virtual onlyFisc {
        require(newFisc != address(0), "Fisc: Fisc cannot be the zero address.");
        _transferFisc(newFisc);
    }

    function _transferFisc(address newFisc) internal virtual {
        emit FiscTransferred(_fisc, newFisc);
        _fisc = newFisc;
    }
}
