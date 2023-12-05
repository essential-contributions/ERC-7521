// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {EmbeddedIntentStandards} from "./EmbeddedIntentStandards.sol";
import {IntentStandardRegistry} from "./IntentStandardRegistry.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IIntentValidatorExecutor} from "../interfaces/IIntentValidatorExecutor.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {getSegmentStandard} from "../standards/utils/SegmentData.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

abstract contract IntentValidatorExecutor is
    IIntentValidatorExecutor,
    ReentrancyGuard,
    EmbeddedIntentStandards,
    IntentStandardRegistry
{
    using IntentSolutionLib for IntentSolution;
    using UserIntentLib for UserIntent;
    using RevertReason for bytes;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;
    uint256 private constant CONTEXT_DATA_MAX_LEN = 2048;

    address private constant EX_STANDARD_NOT_ACTIVE = address(0);
    address private constant EX_STATE_NOT_ACTIVE = address(0);
    address private constant EX_STATE_VALIDATION_EXECUTING =
        address(uint160(uint256(keccak256("EX_STATE_VALIDATION_EXECUTING"))));

    //flag for applications to check current context of execution
    address internal _executionStateContext;
    address internal _executionIntentStandard;

    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     * @param signatureAggregator the allowed signature aggregator.
     * @param validatedIntents the intents that were validated with the signature aggregator.
     */
    function _handleIntents(IntentSolution calldata solution, IAggregator signatureAggregator, bytes32 validatedIntents)
        internal
        nonReentrant
    {
        uint256 intsLen = solution.intents.length;
        require(intsLen > 0, "AA70 no intents");

        // validate timestamp
        uint256 timestamp = solution.getTimestamp();
        require(timestamp > 0, "AA71 invalid timestamp");

        unchecked {
            // validate intents
            for (uint256 i = 0; i < intsLen; i++) {
                UserIntent calldata intent = solution.intents[i];
                bytes32 intentHash = _generateUserIntentHash(intent);
                if (intent.sender != address(0) && intent.intentData.length > 0) {
                    _validateUserIntentWithAccount(intent, intentHash, i, signatureAggregator, validatedIntents);
                }

                emit UserIntentEvent(intentHash, intent.sender, msg.sender);
            }

            // execute solution
            bytes[] memory contextData = new bytes[](solution.intents.length);
            uint256[] memory intentDataIndexes = new uint256[](solution.intents.length);
            uint256 executionIndex = 0;

            // first loop through the order specified by the solution
            for (; executionIndex < solution.order.length; executionIndex++) {
                uint256 intentIndex = solution.order[executionIndex];
                if (intentDataIndexes[intentIndex] < solution.intents[intentIndex].intentData.length) {
                    contextData[intentIndex] = _executeIntent(
                        solution, executionIndex, intentIndex, intentDataIndexes[intentIndex], contextData[intentIndex]
                    );
                    intentDataIndexes[intentIndex]++;
                }
            }

            // continue looping until all intents have finished executing
            while (true) {
                bool finished = true;
                for (uint256 i = 0; i < solution.intents.length; i++) {
                    if (intentDataIndexes[i] < solution.intents[i].intentData.length) {
                        finished = false;
                        contextData[i] =
                            _executeIntent(solution, executionIndex, i, intentDataIndexes[i], contextData[i]);
                        intentDataIndexes[i]++;
                    }
                    executionIndex++;
                }
                if (finished) break;
            }

            // no longer executing
            _executionStateContext = EX_STATE_NOT_ACTIVE;
            _executionIntentStandard = EX_STANDARD_NOT_ACTIVE;
        } //unchecked
    }

    /**
     * Execute a user intent.
     * @param solution the full solution context
     * @param executionIndex the current intent execution index
     * @param intentIndex the user intent index in the solution
     * @param segmentIndex the user intent segment index to execute
     * @param contextData the user intent execution context data
     */
    function _executeIntent(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 intentIndex,
        uint256 segmentIndex,
        bytes memory contextData
    ) private returns (bytes memory) {
        UserIntent calldata intent = solution.intents[intentIndex];
        if (intent.sender != address(0) && intent.intentData.length > 0) {
            bytes32 standardId = getSegmentStandard(intent.intentData[segmentIndex]);
            if (isEmbeddedIntentStandard(standardId)) {
                _executionStateContext = intent.sender;
                _executionIntentStandard = address(this);
                contextData = _executeIntentSegment(solution, executionIndex, segmentIndex, contextData);
            } else {
                IIntentStandard intentStandard = _registeredStandards[standardId];
                if (intentStandard == IIntentStandard(address(0))) {
                    revert FailedIntent(intentIndex, segmentIndex, "AA82 unknown standard");
                }

                _executionStateContext = intent.sender;
                _executionIntentStandard = address(intentStandard);
                bool success = Exec.call(
                    address(intentStandard),
                    0,
                    abi.encodeWithSelector(
                        IIntentStandard.executeIntentSegment.selector,
                        solution,
                        executionIndex,
                        segmentIndex,
                        contextData
                    ),
                    gasleft()
                );
                if (success) {
                    if (Exec.getReturnDataSize() > CONTEXT_DATA_MAX_LEN) {
                        revert FailedIntent(intentIndex, segmentIndex, "AA60 invalid execution context");
                    }
                    contextData = Exec.getReturnDataMax(0x40, CONTEXT_DATA_MAX_LEN);
                } else {
                    bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
                    if (reason.length > 0) {
                        revert FailedIntent(
                            intentIndex,
                            segmentIndex,
                            string.concat("AA61 execution failed: ", string(reason.revertReasonWithoutPadding()))
                        );
                    } else {
                        revert FailedIntent(intentIndex, segmentIndex, "AA61 execution failed (or OOG)");
                    }
                }
            }
        }
        return contextData;
    }

    /**
     * Validate user intent.
     * @param intent the user intent to validate.
     * @param intentHash hash of the user's intent data.
     * @param intentIndex the index of this intent.
     * @param signatureAggregator the allowed signature aggregator.
     * @param validatedIntents the intents that were validated with the signature aggregator.
     */
    function _validateUserIntentWithAccount(
        UserIntent calldata intent,
        bytes32 intentHash,
        uint256 intentIndex,
        IAggregator signatureAggregator,
        bytes32 validatedIntents
    ) internal view {
        // validate intent with account
        try IAccount(intent.sender).validateUserIntent(intent, intentHash) returns (IAggregator aggregator) {
            //check if intent is to be verified by aggregator
            if (aggregator != IAggregator(address(0))) {
                if (aggregator != signatureAggregator) {
                    revert FailedIntent(
                        intentIndex, 0, string.concat("AA24 signature error: invalid signature aggregator")
                    );
                }
                if ((uint256(validatedIntents) & (1 << intentIndex)) == 0) {
                    revert FailedIntent(
                        intentIndex, 0, string.concat("AA24 signature error: intent not part of aggregate")
                    );
                }
            }
        } catch Error(string memory revertReason) {
            revert FailedIntent(intentIndex, 0, string.concat("AA24 signature error: ", revertReason));
        } catch {
            revert FailedIntent(intentIndex, 0, "AA24 signature error (or OOG)");
        }
    }

    /**
     * generates an intent ID for an intent.
     */
    function _generateUserIntentHash(UserIntent calldata intent) internal view returns (bytes32) {
        return keccak256(abi.encode(intent.hash(), address(this), block.chainid));
    }
}
