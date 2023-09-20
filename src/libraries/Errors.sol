// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

library Errors {
    // max period 0 or greater than MAX_PERIODS
    error InvalidMaxPeriod();

    // period duration 0 or greater than MAX_PERIOD_DURATION
    error InvalidPeriodDuration();

    // address provided is not a contract
    error NotAContract();

    // not authorized
    error NotAuthorized();

    // contract already initialized
    error AlreadyInitialized();

    // address(0)
    error InvalidAddress();

    // empty bytes identifier
    error InvalidIdentifier();

    // invalid protocol name
    error InvalidProtocol();

    // invalid number of choices
    error InvalidChoiceCount();

    // invalid input amount
    error InvalidAmount();

    // not team member
    error NotTeamMember();

    // cannot whitelist BRIBE_VAULT
    error NoWhitelistBribeVault();

    // token already whitelisted
    error TokenWhitelisted();

    // token not whitelisted
    error TokenNotWhitelisted();

    // voter already blacklisted
    error VoterBlacklisted();

    // voter not blacklisted
    error VoterNotBlacklisted();

    // deadline has passed
    error DeadlinePassed();

    // invalid period
    error InvalidPeriod();

    // invalid deadline
    error InvalidDeadline();

    // invalid max fee
    error InvalidMaxFee();

    // invalid fee
    error InvalidFee();

    // invalid fee recipient
    error InvalidFeeRecipient();

    // invalid distributor
    error InvalidDistributor();

    // invalid briber
    error InvalidBriber();

    // address does not have DEPOSITOR_ROLE
    error NotDepositor();

    // no array given
    error InvalidArray();

    // invalid reward identifier
    error InvalidRewardIdentifier();

    // bribe has already been transferred
    error BribeAlreadyTransferred();

    // distribution does not exist
    error InvalidDistribution();

    // invalid merkle root
    error InvalidMerkleRoot();

    // token is address(0)
    error InvalidToken();

    // claim does not exist
    error InvalidClaim();

    // reward is not yet active for claiming
    error RewardInactive();

    // timer duration is invalid
    error InvalidTimerDuration();

    // merkle proof is invalid
    error InvalidProof();

    // ETH transfer failed
    error ETHTransferFailed();

    // Invalid operator address
    error InvalidOperator();

    // call to TokenTransferProxy contract
    error TokenTransferProxyCall();

    // calling TransferFrom
    error TransferFromCall();

    // external call failed
    error ExternalCallFailure();

    // returned tokens too few
    error InsufficientReturn();

    // swapDeadline expired
    error DeadlineBreach();

    // expected tokens returned are 0
    error ZeroExpectedReturns();

    // arrays in SwapData.exchangeData have wrong lengths
    error ExchangeDataArrayMismatch();
}
