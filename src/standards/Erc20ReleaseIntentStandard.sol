// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {Erc20ReleaseIntentDelegate} from "./delegates/Erc20ReleaseIntentDelegate.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {_balanceOf, _transfer} from "../utils/wrappers/Erc20Wrapper.sol";
import {Erc20Curve, isRelativeEvaluation, validate, evaluate} from "../utils/curves/Erc20Curve.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * Erc20 Release Intent Segment struct
 * @param standard intent standard id for segment.
 * @param release release curve.
 */
struct Erc20ReleaseIntentSegment {
    bytes32 standard;
    Erc20Curve release;
}

contract Erc20ReleaseIntentStandard is IIntentStandard, Erc20ReleaseIntentDelegate {
    using IntentSolutionLib for IntentSolution;
    using RevertReason for bytes;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {
        if (segmentData.length > 0) {
            Erc20ReleaseIntentSegment calldata segment = parseIntentSegment(segmentData);
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
            Erc20ReleaseIntentSegment calldata segment = parseIntentSegment(intent.intentData[segmentIndex]);
            uint256 evaluateAt = 0;
            if (solution.timestamp > segment.release.timestamp) {
                evaluateAt = solution.timestamp - segment.release.timestamp;
            }

            //release tokens
            address nextExecutingIntentSender = solution.intents[solution.getIntentIndex(executionIndex + 1)].sender;
            _releaseErc20(segment, evaluateAt, intent.sender, nextExecutingIntentSender);

            if (segmentIndex + 1 < intent.intentData.length && intent.intentData[segmentIndex + 1].length > 0) {
                return context;
            }
        }
        return "";
    }

    function parseIntentSegment(bytes calldata segmentData)
        internal
        pure
        returns (Erc20ReleaseIntentSegment calldata segment)
    {
        assembly {
            segment := segmentData.offset
        }
    }

    /**
     * Release tokens.
     * @param intentSegment The intent segment containing the erc20 releases.
     * @param evaluateAt The time offset at which to evaluate the erc20 releases.
     * @param from The address from which to release the erc20.
     * @param to The address to release the erc20.
     */
    function _releaseErc20(
        Erc20ReleaseIntentSegment calldata intentSegment,
        uint256 evaluateAt,
        address from,
        address to
    ) private {
        int256 releaseAmount = evaluate(intentSegment.release, evaluateAt);
        if (releaseAmount > 0) {
            bytes memory data = _encodeReleaseErc20(intentSegment.release, to, uint256(releaseAmount));
            IIntentDelegate(address(from)).generalizedIntentDelegateCall(data);
        }
    }
}
