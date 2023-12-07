// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec} from "../utils/Exec.sol";
import {getSegmentBytes} from "./utils/SegmentData.sol";

/**
 * Simple Call Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [bytes]   callData - the calldata to call on the intent sender
 */
abstract contract SimpleCallCore {
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateSimpleCall(bytes calldata segmentData) internal pure {
        require(segmentData.length >= 32, "Simple Call data is too small");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeSimpleCall(address intentSender, bytes calldata segmentData) internal {
        if (segmentData.length > 32) {
            unchecked {
                bytes memory callData = getSegmentBytes(segmentData, 32, segmentData.length - 32);
                Exec.callAndRevert(intentSender, callData, REVERT_REASON_MAX_LEN);
            }
        }
    }
}

/**
 * Simple Call Intent Standard that can be deployed and registered to the entry point
 */
contract SimpleCall is SimpleCallCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateSimpleCall(segmentData);
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
        _executeSimpleCall(intent.sender, intent.intentData[segmentIndex]);
        return context;
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param callData the calldata to call on the intent sender
 * @return the fully encoded intent standard segment data
 */
function encodeSimpleCallData(bytes32 standardId, bytes memory callData) pure returns (bytes memory) {
    return abi.encodePacked(standardId, callData);
}
