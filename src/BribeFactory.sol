// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IBribeMarket} from "./interfaces/IBribeMarket.sol";
import {IBribeVault} from "./interfaces/IBribeVault.sol";
import {Errors} from "./libraries/Errors.sol";

contract BribeFactory is Ownable2Step {
    address public bribeMarketImplementation;
    address public bribeVault;
    uint256 public constant MAX_PERIODS = 10;
    uint256 public constant MAX_PERIOD_DURATION = 30 days;

    event BribeMarketCreated(address indexed bribeMarket);
    event BribeMarketImplementationUpdated(
        address indexed bribeMarketImplementation
    );
    event BribeVaultUpdated(address indexed bribeVault);

    //    @notice Check if the specified address is a contract
    //    @param  _address : address : address to be checked
    modifier isContract(address _address) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_address)
        }
        if (codeSize == 0) revert Errors.NotAContract();
        _;
    }

    // @param  _implementation : address : address of the Implementation contract
    // @param  _bribeVault     : address : address of the BribeVault
    constructor(address _implementation, address _bribeVault) {
        _setBribeMarketImplementation(_implementation);
        _setBribeVault(_bribeVault);
    }

    //    @notice Deploy a new bribe market
    //    @param  _protocol       : address : market name/identifier
    //    @param  _maxPeriods     : uint256 : maximum number of periods for bribe deposits
    //    @param  _periodDuration : uint256 : period duration of each voting round
    function createBribeMarket(
        string calldata _protocol,
        uint256 _maxPeriods,
        uint256 _periodDuration
    ) external returns (address) {
        if (_maxPeriods == 0 || _maxPeriods > MAX_PERIODS) {
            revert Errors.InvalidMaxPeriod();
        }
        if (_periodDuration == 0 || _periodDuration > MAX_PERIOD_DURATION) {
            revert Errors.InvalidPeriodDuration();
        }

        address bribeMarket = Clones.clone(bribeMarketImplementation);

        IBribeMarket(bribeMarket).initialize(
            bribeVault,
            msg.sender,
            _protocol,
            _maxPeriods,
            _periodDuration
        );
        IBribeVault(bribeVault).grantDepositorRole(bribeMarket);

        emit BribeMarketCreated(bribeMarket);

        return bribeMarket;
    }

    //    @notice Set the BribeMarket implementation address
    //    @param  _implementation : address : implementation address
    function setBribeMarketImplementation(
        address _implementation
    ) external onlyOwner {
        _setBribeMarketImplementation(_implementation);

        emit BribeMarketImplementationUpdated(_implementation);
    }

    //    @notice Set the BribeVault address
    //    @param  _bribeVault : address : BribeVault address
    function setBribeVault(address _bribeVault) external onlyOwner {
        _setBribeVault(_bribeVault);

        emit BribeVaultUpdated(_bribeVault);
    }

    //    @notice Internal method to set the BribeMarket implementation address
    //    @param  _implementation : address : implementation address
    function _setBribeMarketImplementation(
        address _implementation
    ) internal isContract(_implementation) {
        bribeMarketImplementation = _implementation;
    }

    //    @notice Internal method to set the BribeVault address
    //    @param  _bribeVault : address : BribeVault address
    function _setBribeVault(
        address _bribeVault
    ) internal isContract(_bribeVault) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_bribeVault)
        }
        if (codeSize == 0) revert Errors.NotAContract();

        bribeVault = _bribeVault;
    }
}
