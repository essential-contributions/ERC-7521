// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";

/**
 * An Intent standard to check fail cases
 */
contract FailingStandard is IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        //do nothing
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @dev context context data from the previous step in execution (no data means execution is just starting).
     * @return newContext to remember for further execution.
     */
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata
    ) external pure override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];

        //if no data, then just fail with a revert
        if (intent.segments[segmentIndex].length == 32) {
            revert();
        }
        if (intent.segments[segmentIndex].length == 33) {
            revert("test revert");
        }

        //fail by returning way too much context data
        bytes memory tooMuchData = new bytes(2049);
        return tooMuchData;
    }
}
