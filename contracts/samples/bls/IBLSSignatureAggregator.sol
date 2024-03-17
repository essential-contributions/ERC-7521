// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {UserIntent} from "../../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../../interfaces/IntentSolution.sol";

/**
 * Aggregated Signatures validator.
 */
interface IBLSSignatureAggregator {
    /**
     * Execute a batch of UserIntents with an aggregated signature.
     * @param solutions - list of solutions to execute for intents.
     * @param intentsToAggregate - bit field signaling which intents are part of the aggregated signature.
     * @param signature - aggregated signature.
     */
    function handleIntentsAggregated(
        IntentSolution[] calldata solutions,
        bytes32 intentsToAggregate,
        bytes calldata signature
    ) external;

    /**
     * Checks if an intent has been validated through an aggregated signature.
     * @dev used by accounts during their validation process.
     * @param intentHash - the hash of the intent.
     * @return true if an intent with matching hash has been validated.
     */
    function isValidated(bytes32 intentHash) external view returns (bool);

    /**
     * Validate signature of a single intent.
     * @param intent - the intent received from the user.
     */
    function validateSignature(UserIntent calldata intent) external view;

    /**
     * Validate aggregated signature (revert if the aggregated signature does not match the given list of intents).
     * @param intents - array of UserIntents to validate the signature for.
     * @param signature - the aggregated signature.
     */
    function validateSignatures(UserIntent[] calldata intents, bytes calldata signature) external view;

    /**
     * Aggregate multiple signatures into a single value (solver MAY use optimized custom code perform this aggregation).
     * @param intents - array of UserIntents to collect the signatures from.
     * @return aggregatedSignature - the aggregated signature.
     */
    function aggregateSignatures(UserIntent[] calldata intents)
        external
        view
        returns (bytes memory aggregatedSignature);
}
