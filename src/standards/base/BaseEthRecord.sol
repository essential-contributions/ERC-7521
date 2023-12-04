// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseIntentStandard} from "../../interfaces/BaseIntentStandard.sol";
import {UserIntent} from "../../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../../interfaces/IntentSolution.sol";
import {push} from "../utils/ContextData.sol";

/**
 * Eth Record Intent Standard
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 */
abstract contract BaseEthRecord is BaseIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function _validateIntentSegment(bytes calldata segmentData) internal pure virtual override {
        require(segmentData.length != 32, "ETH Record data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @dev unused uint256 - [segmentIndex] the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return newContext to remember for further execution.
     */
    function _executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256,
        bytes memory context
    ) internal virtual override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];

        //push current eth balance to the context data
        return push(context, bytes32(intent.sender.balance));
    }

    /**
     * Helper function to encode intent standard segment data.
     * @param standardId the entry point identifier for this standard
     * @return the fully encoded intent standard segment data
     */
    function encodeData(bytes32 standardId) external pure returns (bytes memory) {
        return abi.encodePacked(standardId);
    }
}
