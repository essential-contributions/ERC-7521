// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseIntentStandard} from "../interfaces/BaseIntentStandard.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {push} from "./utils/ContextData.sol";

/**
 * Eth Record Intent Standard core logic
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

/**
 * Eth Record Intent Standard that can be deployed and registered to the entry point
 */
contract EthRecord is BaseEthRecord, IIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseEthRecord._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseEthRecord._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}

/**
 * Eth Record Intent Standard that can be embedded in entry point
 */
contract EmbeddableEthRecord is BaseEthRecord {
    uint256 private constant _ETH_RECORD_STANDARD_ID = 2;
    bytes32 internal constant ETH_RECORD_STANDARD_ID = bytes32(_ETH_RECORD_STANDARD_ID);

    function getEthRecordStandardId() public pure returns (bytes32) {
        return ETH_RECORD_STANDARD_ID;
    }
}
