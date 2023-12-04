// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IIntentValidatorExecutor {
    /**
     * An event emitted after each successful intent solution
     * @param intentHash - unique identifier for the intent (hash its entire content, except signature).
     * @param sender - the account that generates this intent.
     * @param submitter - the account that submitted the solution for the intent.
     */
    event UserIntentEvent(bytes32 indexed intentHash, address indexed sender, address indexed submitter);

    /**
     * a custom revert error of handleIntents, to identify the offending intent.
     * @param intIndex - index into the array of intents to the failed one
     * @param segIndex - index into the array of intent segments to the failed one
     * @param reason - revert reason
     *  Should be caught in off-chain handleIntents simulation and not happen on-chain.
     *  Useful for mitigating DoS attempts against solvers or for troubleshooting of solution/intent reverts.
     */
    error FailedIntent(uint256 intIndex, uint256 segIndex, string reason);
}
