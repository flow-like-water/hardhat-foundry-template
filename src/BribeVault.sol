// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IPermit2} from "./interfaces/IPermit2.sol";
import {IRewardDistributor} from "./interfaces/IRewardDistributor.sol";
import {Common} from "./libraries/Common.sol";
import {Errors} from "./libraries/Errors.sol";

contract BribeVault is AccessControl {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    struct Bribe {
        address token;
        uint256 amount;
    }

    struct Transfer {
        uint256 feeAmount;
        uint256 distributorAmountTransferred;
        uint256 distributorAmountReceived;
    }

    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    uint256 public constant FEE_DIVISOR = 1_000_000;
    uint256 public immutable FEE_MAX;
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");

    uint256 public fee; // 5000 = 0.5%
    address public feeRecipient; // Fisc (Protocol Treasury)
    address public distributor; // RewardDistributor contract

    // Bribe identifiers mapped to Bribe structs
    // A Bribe identifier is composed of protocol, voting round, etc.
    mapping(bytes32 => Bribe) public bribes;

    // Protocol-specific reward identifiers mapped to bribe identifiers
    // Allows us to group Bribes by reward tokens (one token may be used across many Bribes)
    mapping(bytes32 => bytes32[]) public rewardToBribes;

    // Tracks the reward transfer amounts
    mapping(bytes32 => Transfer) public rewardTransfers;

    // Voter addresses mapped to addresses which will claim rewards on their behalf
    mapping(address => address) public rewardForwarding;

    event SetFee(uint256 _fee);
    event SetFeeRecipient(address _feeRecipient);
    event SetDistributor(address _distributor);
    event DepositBribe(
        address indexed market,
        bytes32 indexed proposal,
        uint256 indexed deadline,
        address token,
        address briber,
        uint256 amount,
        uint256 totalAmount,
        uint256 maxTokensPerVote,
        uint256 periodIndex
    );
    event SetRewardForwarding(address from, address to);
    event TransferBribe(
        bytes32 indexed rewardIdentifier,
        address indexed token,
        uint256 feeAmount,
        uint256 distributorAmount
    );
    event EmergencyWithdrawal(
        address indexed token,
        uint256 amount,
        address admin
    );

    //    @param  _fee          : uint256 : fee
    //    @param  _feeMax       : unt256  : maximum fee
    //    @param  _feeRecipient : address : feeRecipient
    //    @param  _distributor  : address : RewardDistributor address
    constructor(
        uint256 _fee,
        uint256 _feeMax,
        address _feeRecipient,
        address _distributor
    ) {
        // Max fee shouldn't be >= 50%
        if (_feeMax >= FEE_DIVISOR / 2) revert Errors.InvalidMaxFee();
        if (_fee > _feeMax) revert Errors.InvalidFee();
        if (_feeRecipient == address(0)) revert Errors.InvalidFeeRecipient();
        if (_distributor == address(0)) revert Errors.InvalidDistributor();

        FEE_MAX = _feeMax;
        fee = _fee;
        feeRecipient = _feeRecipient;
        distributor = _distributor;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //    @notice Grant the Depositor role to an address
    //    @param  depositor : address : address to grant the Depositor role
    function grantDepositorRole(
        address depositor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (depositor == address(0)) revert Errors.InvalidAddress();

        _grantRole(DEPOSITOR_ROLE, depositor);
    }

    //    @notice Revoke the Depositor role from an address
    //    @param  depositor : address : address to revoke the Depositor role
    function revokeDepositorRole(
        address depositor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // A redundancy to avoid emitting an event if a role has not been revoked
        if (!hasRole(DEPOSITOR_ROLE, depositor)) revert Errors.NotDepositor();

        _revokeRole(DEPOSITOR_ROLE, depositor);
    }

    //    @notice Set the fee to be collected by the protocol
    //    @param  _fee : uint256 : fee
    function setFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_fee > FEE_MAX) revert Errors.InvalidFee();

        fee = _fee;

        emit SetFee(_fee);
    }

    //    @notice Set the address where fees will accrue
    //    @param  _feeRecipient : address : feeRecipient
    function setFeeRecipient(
        address _feeRecipient
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_feeRecipient == address(0)) revert Errors.InvalidFeeRecipient();

        feeRecipient = _feeRecipient;

        emit SetFeeRecipient(_feeRecipient);
    }

    //    @notice Set the RewardDistributor contract address
    //    @param _distributor : address : Distributor
    function setDistributor(
        address _distributor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_distributor == address(0)) revert Errors.InvalidDistributor();

        distributor = _distributor;

        emit SetDistributor(_distributor);
    }

    //    @notice Generate the BribeVault identifier based on the given scheme
    //    @param  _market           : address : market that originated the Bribe
    //    @param  _proposal         : bytes32 : proposal
    //    @param  _proposalDeadline : uint256 : proposal deadline
    //    @param  _token            : address : token
    //    @return id                : bytes32 : BribeVault identifier

    function generateBribeVaultIdentifier(
        address _market,
        bytes32 _proposal,
        uint256 _proposalDeadline,
        address _token
    ) public pure returns (bytes32 id) {
        id = keccak256(
            abi.encodePacked(_market, _proposal, _proposalDeadline, _token)
        );
    }

    //    @notice Generate the reward identifier based on a scheme
    //    @param  _market           : address : market that originated the reward
    //    @param  _proposalDeadline : uint256 : proposal deadline
    //    @param  _token            : address : token
    //    @return id                : bytes32 : reward identifier
    function generateRewardIdentifier(
        address _market,
        address _token,
        uint256 _proposalDeadline
    ) public pure returns (bytes32 id) {
        id = keccak256(abi.encodePacked(_market, _proposalDeadline, _token));
    }

    //    @notice Get Bribe information based on the specified identifier
    //    @param  bribeIdentifier : bytes32 : the specified Bribe identifier
    function getBribe(
        bytes32 bribeIdentifier
    ) external view returns (address token, uint256 amount) {
        Bribe memory b = bribes[bribeIdentifier];
        return (b.token, b.amount);
    }

    //    @notice Return a list of Bribe identifiers tied to the specified reward identifier
    function getBribeIdentifiersByRewardIdentifier(
        bytes32 rewardIdentifier
    ) external view returns (bytes32[] memory) {
        return rewardToBribes[rewardIdentifier];
    }

    //    @notice Use permit to perform token transfer
    //    @param  _dp : DepositBribeParams : Deposit data
    function _transferWithPermit(
        Common.DepositBribeParams calldata _dp
    ) internal {
        // Get current nonce
        (, , uint48 nonce) = PERMIT2.allowance(
            _dp.briber,
            _dp.token,
            address(this)
        );

        // Approve the transfer
        PERMIT2.permit(
            _dp.briber,
            IPermit2.PermitSingle({
                details: IPermit2.PermitDetails({
                    token: _dp.token,
                    amount: _dp.amount.toUint160(),
                    expiration: 2 ** 48 - 1,
                    nonce: nonce
                }),
                spender: address(this),
                sigDeadline: _dp.permitDeadline
            }),
            _dp.signature
        );

        // Transfer the tokens
        PERMIT2.transferFrom(
            _dp.briber,
            address(this),
            _dp.amount.toUint160(),
            _dp.token
        );
    }

    //    @notice Deposit bribe (ERC20 only)
    //    @param  _dp : DepositBribeParams : Deposit data
    function depositBribe(
        Common.DepositBribeParams calldata _dp
    ) external onlyRole(DEPOSITOR_ROLE) {
        if (_dp.token == address(0)) revert Errors.InvalidToken();
        if (_dp.amount == 0) revert Errors.InvalidAmount();
        if (_dp.briber == address(0)) revert Errors.InvalidBriber();

        // Store the balance before transfer to calculate post-fee amount
        uint256 balanceBeforeTransfer = IERC20(_dp.token).balanceOf(
            address(this)
        );

        // Transfer the tokens to this contract
        // Uses Permit2 if a signature is provided
        if (_dp.signature.length > 0) {
            _transferWithPermit(_dp);
        } else {
            IERC20(_dp.token).safeTransferFrom(
                _dp.briber,
                address(this),
                _dp.amount
            );
        }

        // The difference between balances before and after the transfer is the actual bribe amount
        uint256 totalBribeAmount = IERC20(_dp.token).balanceOf(address(this)) -
            balanceBeforeTransfer;

        // Declare bribe data
        bytes32 bribeIdentifier;
        uint256 bribeAmount;
        uint256 deadline;

        // Loop through the specified periods
        uint256 i;
        do {
            deadline = _dp.proposalDeadline + (i * _dp.periodDuration);

            // Generate the bribeIdentifier
            bribeIdentifier = generateBribeVaultIdentifier(
                msg.sender,
                _dp.proposal,
                deadline,
                _dp.token
            );

            Bribe storage b = bribes[bribeIdentifier];

            // Increase bribeAmount and add round error to first period
            bribeAmount =
                (totalBribeAmount / _dp.periods) +
                (i == 0 ? totalBribeAmount % _dp.periods : 0);

            b.amount += bribeAmount;

            // Only set the token address and update the reward-to-bribe mapping if not yet set
            if (b.token == address(0)) {
                b.token = _dp.token;
                rewardToBribes[
                    generateRewardIdentifier(msg.sender, _dp.token, deadline)
                ].push(bribeIdentifier);
            }

            emitDepositBribe(_dp, bribeAmount, deadline, bribeIdentifier, i);

            unchecked {
                ++i;
            }
        } while (i < _dp.periods);
    }

    function emitDepositBribe(
        Common.DepositBribeParams calldata _dp,
        uint256 bribeAmount,
        uint256 deadline,
        bytes32 bribeIdentifier,
        uint256 i
    ) internal {
        emit DepositBribe(
            msg.sender,
            _dp.proposal,
            deadline,
            _dp.token,
            _dp.briber,
            bribeAmount,
            bribes[bribeIdentifier].amount,
            _dp.maxTokensPerVote,
            i
        );
    }

    //    @notice Voters can opt in or out of reward-forwarding
    //    @notice Opt-in  - a voter sets another address to forward rewards to
    //    @notice Opt-out - a voter sets their own address or the zero address
    //    @param  to : address : account that rewards will be sent to
    function setRewardForwarding(address to) external {
        rewardForwarding[msg.sender] = to;

        emit SetRewardForwarding(msg.sender, to);
    }

    //    @notice Calculate transfer amounts
    //    @param  rewardIdentifier  : bytes32 : unique identifier related to reward
    //    @return feeAmount         : uint256 : amount sent to the protocol treasury
    //    @return distributorAmount : uint256 : amount sent to the RewardDistributor
    function calculateTransferAmounts(
        bytes32 rewardIdentifier
    ) private view returns (uint256 feeAmount, uint256 distributorAmount) {
        bytes32[] memory bribeIdentifiers = rewardToBribes[rewardIdentifier];
        uint256 totalAmount;
        uint256 bLen = bribeIdentifiers.length;

        for (uint256 i; i < bLen; ) {
            totalAmount += bribes[bribeIdentifiers[i]].amount;

            unchecked {
                ++i;
            }
        }

        feeAmount = (totalAmount * fee) / FEE_DIVISOR;
        distributorAmount = totalAmount - feeAmount;
    }

    //    @notice Transfer fees to feeRecipient and Bribes to Distributor and update the reward metadata
    //    @param  rewardIdentifiers : bytes32[] : list of rewardIdentifiers
    //
    function transferBribes(
        bytes32[] calldata rewardIdentifiers
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 rLen = rewardIdentifiers.length;

        if (rLen == 0) revert Errors.InvalidArray();

        // Transfer the Bribe funds to feeRecipient and RewardDistributor
        for (uint256 i; i < rLen; ) {
            bytes32 rewardIdentifier = rewardIdentifiers[i];
            if (rewardToBribes[rewardIdentifier].length == 0) {
                revert Errors.InvalidRewardIdentifier();
            }

            Transfer storage r = rewardTransfers[rewardIdentifier];

            address token = bribes[rewardToBribes[rewardIdentifier][0]].token;
            (
                uint256 feeAmount,
                uint256 distributorAmount
            ) = calculateTransferAmounts(rewardIdentifier);

            if (r.distributorAmountTransferred == distributorAmount) {
                revert Errors.BribeAlreadyTransferred();
            }

            uint256 feeToTransfer = feeAmount - r.feeAmount;
            uint256 distributorAmountToTransfer = distributorAmount -
                r.distributorAmountTransferred;

            // Set the "before fee" field to prevent duplicate transfers
            r.feeAmount = feeAmount;
            r.distributorAmountTransferred = distributorAmount;

            IERC20 t = IERC20(token);

            // Necessary to calculate the "after fee" amount received by the Distributor
            uint256 distributorBalance = t.balanceOf(distributor);

            t.safeTransfer(feeRecipient, feeToTransfer);
            t.safeTransfer(distributor, distributorAmountToTransfer);

            // Set the "after fee" field to record the actual amount received by the Distributor
            uint256 finalAmountReceived = t.balanceOf(distributor) -
                distributorBalance;
            r.distributorAmountReceived += finalAmountReceived;

            emit TransferBribe(
                rewardIdentifier,
                token,
                feeAmount,
                finalAmountReceived
            );

            unchecked {
                ++i;
            }
        }
    }

    //    @notice Withdraw ERC20 tokens to the admin address
    //    @param  token  : address : token address
    //    @param  amount : uint256 : token amount
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) revert Errors.InvalidToken();
        if (amount == 0) revert Errors.InvalidAmount();

        IERC20(token).safeTransfer(msg.sender, amount);

        emit EmergencyWithdrawal(token, amount, msg.sender);
    }
}
