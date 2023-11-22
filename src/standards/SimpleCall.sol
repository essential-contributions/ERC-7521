// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {EmbeddedStandard} from "../core/EmbeddedStandard.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec} from "../utils/Exec.sol";
import {getSegmentBytes} from "./utils/SegmentData.sol";

/**
 * Simple Call Intent Standard
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [bytes]   callData - the calldata to call on the intent sender
 */
contract SimpleCall is IIntentStandard, EmbeddedStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Basic state and constants.
     */
    bytes32 internal constant CALL_INTENT_STANDARD_ID = 0;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    function getStandardId() public pure override returns (bytes32) {
        return CALL_INTENT_STANDARD_ID;
    }

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {
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
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        uint256 segmentDataLength = intent.intentData[segmentIndex].length;
        if (segmentDataLength > 32) {
            unchecked {
                bytes memory callData = getSegmentBytes(context, 32, segmentDataLength - 32);
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
