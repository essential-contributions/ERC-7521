// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import {INonceManager} from "./INonceManager.sol";
import {IIntentStandard} from "./IIntentStandard.sol";
import {UserIntent} from "./UserIntent.sol";

interface IEntryPoint is INonceManager {
    /**
     * An event emitted after each successful intent solution
     * @param intentHash - unique identifier for the intent (hash its entire content, except signature).
     * @param sender - the account that generates this intent.
     * @param submitter - the account that submitted the solution for the intent.
     * @param nonce - the nonce value from the intent.
     */
    event UserIntentEvent(bytes32 indexed intentHash, address indexed sender, address indexed submitter, uint256 nonce);

    /**
     * An event emitted if the UserIntent part of the solution reverted
     * @param solIndex - index into the array of solutions to the failed one (in simulateValidation, this is always zero).
     * @param intIndex - index into the array of intents to the failed one.
     * @param segIndex - index into the array of intent segments to the failed one.
     * @param revertReason - the return bytes from the (reverted) call.
     */
    event UserIntentRevertReason(uint256 solIndex, uint256 intIndex, uint256 segIndex, string revertReason);

    /**
     * An event emitted if the solution steps reverted
     * @param solIndex - index into the array of solutions to the failed one (in simulateValidation, this is always zero).
     * @param stepIndex the index of the solution step.
     * @param revertReason - the return bytes from the (reverted) call to "callData".
     */
    event SolutionRevertReason(uint256 solIndex, uint256 stepIndex, string revertReason);

    /**
     * an event emitted by handleIntents, before starting the execution loop.
     * any event emitted before this event, is part of the validation.
     */
    event BeforeExecution();

    /**
     * a custom revert error of handleIntents, to identify the offending intent.
     * NOTE: if simulateValidation passes successfully, there should be no reason for handleIntents to fail.
     * @param intIndex - index into the array of intents to the failed one
     * @param segIndex - index into the array of intent segments to the failed one
     * @param reason - revert reason
     *  Should be caught in off-chain handleIntents simulation and not happen on-chain.
     *  Useful for mitigating DoS attempts against solvers or for troubleshooting of solution/intent reverts.
     */
    error FailedIntent(uint256 intIndex, uint256 segIndex, string reason);

    /**
     * a custom revert error of handleIntents, to identify the offending solution.
     * NOTE: if simulateValidation passes successfully, there should be no reason for handleIntents to fail.
     * @param stepIndex the index of the solution step.
     * @param reason - revert reason
     *  Should be caught in off-chain handleIntents simulation and not happen on-chain.
     *  Useful for mitigating DoS attempts against solvers or for troubleshooting of solution/intent reverts.
     */
    error FailedSolution(uint256 stepIndex, string reason);

    /**
     * Successful result from simulateValidation.
     * @param sigFailed - UserIntent signature check failed
     * @param validAfter - first timestamp this UserIntent is valid
     * @param validUntil - last timestamp this UserIntent is valid
     */
    error ValidationResult(bool sigFailed, uint48 validAfter, uint48 validUntil);

    /**
     * return value of simulateHandleIntents
     */
    error ExecutionResult(bool success, bool targetSuccess, bytes targetResult);

    //UserIntents handled, per solution
    struct IntentSolution {
        uint256 timestamp;
        UserIntent[] intents;
        SolutionSegment[] solutionSegments;
    }

    //CallDataSteps are called directly to the intent standard contract with zero value
    struct SolutionSegment {
        bytes[] callDataSteps;
    }

    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     */
    function handleIntents(IntentSolution calldata solution) external;

    /**
     * Execute a batch of UserIntents using multiple solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleMultiSolutionIntents(IntentSolution[] calldata solutions) external;

    /**
     * simulate full execution of a UserIntent solution (including both validation and target execution)
     * this method will always revert with "ExecutionResult".
     * it performs full validation of the UserIntent solution, but ignores signature error.
     * an optional target address is called after the solution succeeds, and its value is returned
     * (before the entire call is reverted)
     * Note that in order to collect the the success/failure of the target call, it must be executed
     * with trace enabled to track the emitted events.
     * @param solution the UserIntent solution to simulate.
     * @param timestamp the timestamp at which to evaluate the intents (acts in place of block.timestamp).
     * @param target if nonzero, a target address to call after user intent simulation. If called,
     *        the targetSuccess and targetResult are set to the return from that call.
     * @param targetCallData callData to pass to target address.
     */
    function simulateHandleIntents(
        IntentSolution calldata solution,
        uint256 timestamp,
        address target,
        bytes calldata targetCallData
    ) external;

    /**
     * Simulate a call to account.validateUserIntent.
     * @dev this method always revert. Successful result is ValidationResult error. other errors are failures.
     * @dev The node must also verify it doesn't use banned opcodes, and that it doesn't reference storage outside the account's data.
     * @param intent the user intent to validate.
     */
    function simulateValidation(UserIntent calldata intent) external;

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the intent (except the signature), the entrypoint and the chainid.
     */
    function getUserIntentHash(UserIntent calldata intent) external view returns (bytes32);

    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(IIntentStandard intentStandard) external returns (bytes32);

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IIntentStandard);

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(IIntentStandard intentStandard) external view returns (bytes32);

    /**
     * returns if intent validation actions are currently being executed.
     */
    function validationExecuting() external view returns (bool);

    /**
     * returns if intent solution specific actions are currently being executed.
     */
    function solutionExecuting() external view returns (bool);

    /**
     * returns the sender of the currently executing intent (or address(0) is no intent is executing).
     */
    function executingIntentSender() external view returns (address);
}
