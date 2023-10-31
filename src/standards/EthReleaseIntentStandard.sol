// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import "forge-std/Test.sol";
import {EthCurve, isRelativeEvaluation, validate, evaluate} from "../utils/curves/EthCurve.sol";
import {EthReleaseIntentDelegate} from "./delegates/EthReleaseIntentDelegate.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * Eth Release Intent Segment struct
 * @param standard intent standard id for segment.
 * @param release release curve.
 */
struct EthReleaseIntentSegment {
    bytes32 standard;
    EthCurve release;
}

contract EthReleaseIntentStandard is IIntentStandard, EthReleaseIntentDelegate {
    using IntentSolutionLib for IntentSolution;
    using RevertReason for bytes;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {
        if (segmentData.length > 0) {
            EthReleaseIntentSegment calldata segment = parseIntentSegment(segmentData);
            validate(segment.release);
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
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) external returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        if (intent.intentData[segmentIndex].length > 0) {
            uint256 evaluateAt = 0;
            if (solution.timestamp > intent.timestamp) {
                evaluateAt = solution.timestamp - intent.timestamp;
            }
            EthReleaseIntentSegment calldata segment = parseIntentSegment(intent.intentData[segmentIndex]);

            //release tokens
            address nextExecutingIntentSender = solution.intents[solution.getIntentIndex(executionIndex + 1)].sender;
            _releaseEth(segment, evaluateAt, intent.sender, nextExecutingIntentSender);

            return context;
        }
        return "";
    }

    function parseIntentSegment(bytes calldata segmentData)
        internal
        pure
        returns (EthReleaseIntentSegment calldata segment)
    {
        assembly {
            segment := segmentData.offset
        }
    }

    /**
     * Release eth.
     * @param intentSegment The intent segment containing the eth release.
     * @param evaluateAt The time offset at which to evaluate the eth release.
     * @param from The address from which to release the eth.
     * @param to The address to release the eth.
     */
    function _releaseEth(EthReleaseIntentSegment calldata intentSegment, uint256 evaluateAt, address from, address to)
        private
    {
        int256 releaseAmount = evaluate(intentSegment.release, evaluateAt);
        if (releaseAmount > 0) {
            bytes memory data = _encodeReleaseEth(to, uint256(releaseAmount));
            IIntentDelegate(address(from)).generalizedIntentDelegateCall(data);
        }
    }

    function testNothingAtAll() public {}
}
