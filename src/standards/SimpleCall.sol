// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseIntentStandard} from "../interfaces/BaseIntentStandard.sol";
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
abstract contract BaseSimpleCall is BaseIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Basic state and constants.
     */
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function _validateIntentSegment(bytes calldata segmentData) internal pure virtual override {
        require(segmentData.length >= 32, "Simple Call data is too small");
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution.
     */
    function _executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) internal virtual override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        bytes calldata segment = intent.intentData[segmentIndex];
        if (segment.length > 32) {
            unchecked {
                bytes memory callData = getSegmentBytes(segment, 32, segment.length - 32);
                Exec.callAndRevert(intent.sender, callData, REVERT_REASON_MAX_LEN);
            }
        }

        //return context unchanged
        return context;
    }

    /**
     * Helper function to encode intent standard segment data.
     * @param standardId the entry point identifier for this standard
     * @param callData the calldata to call on the intent sender
     * @return the fully encoded intent standard segment data
     */
    function encodeData(bytes32 standardId, bytes memory callData) external pure returns (bytes memory) {
        return abi.encodePacked(standardId, callData);
    }
}

/**
 * Simple Call Intent Standard that can be deployed and registered to the entry point
 */
contract SimpleCall is BaseSimpleCall, IIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseSimpleCall._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseSimpleCall._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}

/**
 * Simple Call Intent Standard that can be embedded in entry point
 */
contract EmbeddableSimpleCall is BaseSimpleCall {
    bytes32 internal constant SIMPLE_CALL_STANDARD_ID = 0;

    function getSimpleCallStandardId() public pure returns (bytes32) {
        return SIMPLE_CALL_STANDARD_ID;
    }
}
