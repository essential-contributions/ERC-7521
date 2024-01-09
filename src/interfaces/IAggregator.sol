// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.22;

import {UserIntent} from "./UserIntent.sol";

/**
 * Aggregated Signatures validator.
 */
interface IAggregator {
    /**
     * Validate aggregated signature.
     * Revert if the aggregated signature does not match the given list of intents.
     * @param intents   - Array of UserIntents to validate the signature for.
     * @param signature - The aggregated signature.
     */
    function validateSignatures(UserIntent[] calldata intents, bytes calldata signature) external view;

    /**
     * Validate signature of a single intent.
     * This method is should be called by bundler after EntryPoint.simulateValidation() returns (reverts) with ValidationResultWithAggregation
     * First it validates the signature over the intent. Then it returns data to be used when creating the handleIntents.
     * @param intent        - The intent received from the user.
     * @return sigForIntent - The value to put into the signature field of the intent when calling handleIntents.
     *                        (usually empty, unless account and aggregator support some kind of "multisig")
     */
    function validateIntentSignature(UserIntent calldata intent) external view returns (bytes memory sigForIntent);

    /**
     * Aggregate multiple signatures into a single value.
     * This method is called off-chain to calculate the signature to pass with handleIntents()
     * bundler MAY use optimized custom code perform this aggregation.
     * @param intents              - Array of UserIntents to collect the signatures from.
     * @return aggregatedSignature - The aggregated signature.
     */
    function aggregateSignatures(UserIntent[] calldata intents)
        external
        view
        returns (bytes memory aggregatedSignature);
}
