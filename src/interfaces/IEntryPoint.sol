// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseIntentStandard} from "./BaseIntentStandard.sol";
import {DeployableIntentStandard} from "./DeployableIntentStandard.sol";
import {IIntentStandardRegistry} from "./IIntentStandardRegistry.sol";
import {IIntentValidatorExecutor} from "./IIntentValidatorExecutor.sol";
import {INonceManager} from "./INonceManager.sol";
import {IntentSolution} from "./IntentSolution.sol";
import {IAggregator} from "./IAggregator.sol";
import {UserIntent} from "./UserIntent.sol";

interface IEntryPoint is INonceManager {
    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     */
    function handleIntents(IntentSolution calldata solution) external;

    /**
     * Execute a batch of UserIntents using multiple solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleIntentsMulti(IntentSolution[] calldata solutions) external;

    /**
     * Execute a batch of UserIntents with an aggregated signature.
     * @param solutions list of solutions to execute for intents.
     * @param aggregator address of aggregator.
     * @param intentsToAggregate bit field signaling which intents are part of the aggregated signature.
     * @param signature aggregated signature.
     */
    function handleIntentsAggregated(
        IntentSolution[] calldata solutions,
        IAggregator aggregator,
        bytes32 intentsToAggregate,
        bytes calldata signature
    ) external;

    /**
     * Run validation for the given intent.
     * @dev This method is view only.
     * @param intent the user intent to validate.
     */
    function validateIntent(UserIntent calldata intent) external view;

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the intent (except the signature), the entrypoint and the chainid.
     */
    function getUserIntentHash(UserIntent calldata intent) external view returns (bytes32);

    /**
     * returns true if the given standard is currently executing an intent segment for the msg.sender.
     */
    function verifyExecutingIntentSegmentForStandard(BaseIntentStandard intentStandard) external returns (bool);
}
