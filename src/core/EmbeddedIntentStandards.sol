// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseIntentStandard} from "../interfaces/BaseIntentStandard.sol";
import {IntentSolutionLib, IntentSolution} from "../interfaces/IntentSolution.sol";
import {EmbeddableSimpleCall} from "../standards/embeddable/EmbeddableSimpleCall.sol";
import {EmbeddableUserOperation} from "../standards/embeddable/EmbeddableUserOperation.sol";
import {EmbeddableEthRecord} from "../standards/embeddable/EmbeddableEthRecord.sol";
import {EmbeddableEthRequire} from "../standards/embeddable/EmbeddableEthRequire.sol";
import {EmbeddableEthRelease} from "../standards/embeddable/EmbeddableEthRelease.sol";
import {BaseSimpleCall} from "../standards/base/BaseSimpleCall.sol";
import {BaseUserOperation} from "../standards/base/BaseUserOperation.sol";
import {BaseEthRecord} from "../standards/base/BaseEthRecord.sol";
import {BaseEthRequire} from "../standards/base/BaseEthRequire.sol";
import {BaseEthRelease} from "../standards/base/BaseEthRelease.sol";
import {getSegmentWord, getSegmentStandard} from "../standards/utils/SegmentData.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";

contract EmbeddedIntentStandards is
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
