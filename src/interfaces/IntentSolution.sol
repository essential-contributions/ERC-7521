// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable private-vars-leading-underscore */

import {UserIntent} from "./UserIntent.sol";

/**
 * Intent Solution struct
 * @param timestamp the time to evaluate the intents at.
 * @param intents list of intents to solve.
 * @param order the order to execute the intents.
 */
struct IntentSolution {
    uint256 timestamp;
    UserIntent[] intents;
    uint256[] order;
}

/**
 * Utility functions helpful when working with IntentSolution structs.
 */
library IntentSolutionLib {
    uint256 private constant TIMESTAMP_MAX_OVER = 6;
    uint256 private constant TIMESTAMP_NULL = 0;

    /**
     * Get the timestamp to evaluate the intents at.
     * @param solution The IntentSolution struct.
     * @return The timestamp to use for evaluating intents.
     */
    function getTimestamp(IntentSolution calldata solution) internal view returns (uint256) {
        if (solution.timestamp == TIMESTAMP_NULL) return block.timestamp;
        uint256 timestamp = solution.timestamp;
        if (timestamp < block.timestamp || (timestamp - block.timestamp) <= TIMESTAMP_MAX_OVER) return timestamp;
        return 0;
    }

    /**
     * Get the index of an intent to be executed based on its execution index.
     * @param solution The IntentSolution struct.
     * @param executionIndex The current index of execution.
     * @return The index of the intent to be executed.
     */
    function getIntentIndex(IntentSolution calldata solution, uint256 executionIndex) internal pure returns (uint256) {
        if (executionIndex < solution.order.length) return solution.order[executionIndex];
        return (executionIndex - solution.order.length) % solution.intents.length;
    }
}
