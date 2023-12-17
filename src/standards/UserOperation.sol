// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec} from "../utils/Exec.sol";
import {getSegmentWord, getSegmentBytes} from "./utils/SegmentData.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * User Operation Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [uint32]  callGasLimit - the max gas for executing the call
 *   [bytes]   callData - the calldata to call on the intent sender
 */
abstract contract UserOperationCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateUserOperation(bytes calldata segmentData) internal pure {
        require(segmentData.length >= 36, "User Operation data is too small");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeUserOperation(address intentSender, bytes calldata segmentData) internal {
        if (segmentData.length > 36) {
            unchecked {
                uint32 callGasLimit = uint32(uint256(getSegmentWord(segmentData, 4)));
                bytes memory callData = getSegmentBytes(segmentData, 36, segmentData.length - 36);
                Exec.call(intentSender, 0, callData, callGasLimit);
            }
        }
    }
}

/**
 * User Operation Intent Standard that can be deployed and registered to the entry point
 */
contract UserOperation is UserOperationCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateUserOperation(segmentData);
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return newContext to remember for further execution.
     */
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        _executeUserOperation(intent.sender, intent.intentData[segmentIndex]);
        return context;
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param callGasLimit the max gas for executing the call
 * @param callData the calldata to call on the intent sender
 * @return the fully encoded intent standard segment data
 */
function encodeUserOperationData(bytes32 standardId, uint32 callGasLimit, bytes memory callData)
    pure
    returns (bytes memory)
{
    return abi.encodePacked(standardId, callGasLimit, callData);
}
