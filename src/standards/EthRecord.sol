// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {push} from "./utils/ContextData.sol";

/**
 * Eth Record Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 */
abstract contract EthRecordCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateEthRecord(bytes calldata segmentData) internal pure {
        require(segmentData.length != 32, "ETH Record data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeEthRecord(address intentSender, bytes memory context) internal view returns (bytes memory) {
        //push current eth balance to the context data
        return push(context, bytes32(intentSender.balance));
    }
}

/**
 * Eth Record Intent Standard that can be deployed and registered to the entry point
 */
contract EthRecord is EthRecordCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateEthRecord(segmentData);
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @dev unused uint256 - [segmentIndex] the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return newContext to remember for further execution.
     */
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256,
        bytes calldata context
    ) external view override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        return _executeEthRecord(intent.sender, context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @return the fully encoded intent standard segment data
 */
function encodeEthRecordData(bytes32 standardId) pure returns (bytes memory) {
    return abi.encodePacked(standardId);
}
