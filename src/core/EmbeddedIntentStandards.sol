// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseIntentStandard} from "../interfaces/BaseIntentStandard.sol";
import {IntentSolutionLib, IntentSolution} from "../interfaces/IntentSolution.sol";
import {EmbeddableSimpleCall} from "../standards/SimpleCall.sol";
import {EmbeddableUserOperation} from "../standards/UserOperation.sol";
import {EmbeddableEthRecord} from "../standards/EthRecord.sol";
import {EmbeddableEthRequire} from "../standards/EthRequire.sol";
import {EmbeddableEthRelease} from "../standards/EthRelease.sol";
import {BaseSimpleCall} from "../standards/SimpleCall.sol";
import {BaseUserOperation} from "../standards/UserOperation.sol";
import {BaseEthRecord} from "../standards/EthRecord.sol";
import {BaseEthRequire} from "../standards/EthRequire.sol";
import {BaseEthRelease} from "../standards/EthRelease.sol";
import {getSegmentWord, getSegmentStandard} from "../standards/utils/SegmentData.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";

abstract contract EmbeddedIntentStandards is
    EmbeddableSimpleCall,
    EmbeddableUserOperation,
    EmbeddableEthRecord,
    EmbeddableEthRequire,
    EmbeddableEthRelease
{
    using IntentSolutionLib for IntentSolution;

    function isEmbeddedIntentStandard(bytes32 standardId) public pure returns (bool) {
        return standardId == SIMPLE_CALL_STANDARD_ID || standardId == USER_OPERATION_STANDARD_ID
            || standardId == ETH_RECORD_STANDARD_ID || standardId == ETH_REQUIRE_STANDARD_ID
            || standardId == ETH_RELEASE_STANDARD_ID;
    }

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function _validateIntentSegment(bytes calldata segmentData)
        internal
        pure
        override(BaseSimpleCall, BaseUserOperation, BaseEthRecord, BaseEthRequire, BaseEthRelease)
    {
        bytes32 standardId = getSegmentStandard(segmentData);
        if (standardId == SIMPLE_CALL_STANDARD_ID) {
            BaseSimpleCall._validateIntentSegment(segmentData);
        } else if (standardId == USER_OPERATION_STANDARD_ID) {
            BaseUserOperation._validateIntentSegment(segmentData);
        } else if (standardId == ETH_RECORD_STANDARD_ID) {
            BaseEthRecord._validateIntentSegment(segmentData);
        } else if (standardId == ETH_REQUIRE_STANDARD_ID) {
            BaseEthRequire._validateIntentSegment(segmentData);
        } else if (standardId == ETH_RELEASE_STANDARD_ID) {
            BaseEthRelease._validateIntentSegment(segmentData);
        } else {
            revert("Cannot validate invalid standard");
        }
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
    )
        internal
        override(BaseSimpleCall, BaseUserOperation, BaseEthRecord, BaseEthRequire, BaseEthRelease)
        returns (bytes memory)
    {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        bytes32 standardId = getSegmentStandard(intent.intentData[segmentIndex]);
        if (standardId == SIMPLE_CALL_STANDARD_ID) {
            return BaseSimpleCall._executeIntentSegment(solution, executionIndex, segmentIndex, context);
        } else if (standardId == USER_OPERATION_STANDARD_ID) {
            return BaseUserOperation._executeIntentSegment(solution, executionIndex, segmentIndex, context);
        } else if (standardId == ETH_RECORD_STANDARD_ID) {
            return BaseEthRecord._executeIntentSegment(solution, executionIndex, segmentIndex, context);
        } else if (standardId == ETH_REQUIRE_STANDARD_ID) {
            return BaseEthRequire._executeIntentSegment(solution, executionIndex, segmentIndex, context);
        } else if (standardId == ETH_RELEASE_STANDARD_ID) {
            return BaseEthRelease._executeIntentSegment(solution, executionIndex, segmentIndex, context);
        } else {
            revert("Cannot execute invalid standard");
        }
    }
}
