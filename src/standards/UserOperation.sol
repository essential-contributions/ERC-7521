// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec} from "../utils/Exec.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * User Operation Segment struct
 * @param standard intent standard id for segment.
 * @param callGasLimit max gas to be spent on the call data.
 * @param callData the desired call data.
 */
struct UserOperationSegment {
    bytes32 standard;
    uint256 callGasLimit;
    bytes callData;
}

contract UserOperation is IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {}

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution.
     */
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) external returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];

        if (intent.intentData[segmentIndex].length > 0) {
            UserOperationSegment calldata dataSegment = parseIntentSegment(intent.intentData, segmentIndex);

            //execute calldata
            if (dataSegment.callData.length > 0) {
                Exec.call(intent.sender, 0, dataSegment.callData, dataSegment.callGasLimit);
                if (segmentIndex + 1 < intent.intentData.length && intent.intentData[segmentIndex + 1].length > 0) {
                    return context;
                }
            }
        }
        return "";
    }

    function parseIntentSegment(bytes[] calldata intentData, uint256 segmentIndex)
        internal
        pure
        returns (UserOperationSegment calldata segment)
    {
        bytes calldata data = intentData[segmentIndex];
        assembly {
            segment := data.offset
        }
    }
}
