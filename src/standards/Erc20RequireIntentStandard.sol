// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {Erc20Curve, isRelativeEvaluation, validate, evaluate} from "../utils/curves/Erc20Curve.sol";
import {_balanceOf} from "../utils/wrappers/Erc20Wrapper.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * Erc20 Require Intent Segment struct
 * @param standard intent standard id for segment.
 * @param requirement asset that is required to be owned by the account at the end of the solution execution.
 */
struct Erc20RequireIntentSegment {
    bytes32 standard;
    Erc20Curve requirement;
}

contract Erc20RequireIntentStandard is IIntentStandard {
    using IntentSolutionLib for IntentSolution;
    using RevertReason for bytes;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {
        if (segmentData.length > 0) {
            Erc20RequireIntentSegment calldata segment = parseIntentSegment(segmentData);
            validate(segment.requirement);
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
    ) external view returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        if (intent.intentData[segmentIndex].length > 0) {
            Erc20RequireIntentSegment calldata segment = parseIntentSegment(intent.intentData[segmentIndex]);
            uint256 evaluateAt = 0;
            if (solution.timestamp > segment.requirement.timestamp) {
                evaluateAt = solution.timestamp - segment.requirement.timestamp;
            }

            // check requirement
            _checkRequirement(segment, evaluateAt, intent.sender);

            if (segmentIndex + 1 < intent.intentData.length && intent.intentData[segmentIndex + 1].length > 0) {
                return context;
            }
        }
        return "";
    }

    function parseIntentSegment(bytes calldata segmentData)
        internal
        pure
        returns (Erc20RequireIntentSegment calldata segment)
    {
        assembly {
            segment := segmentData.offset
        }
    }

    function _checkRequirement(Erc20RequireIntentSegment calldata intentSegment, uint256 evaluateAt, address owner)
        private
        view
    {
        int256 requiredBalance = evaluate(intentSegment.requirement, evaluateAt);
        uint256 currentBalance = _balanceOf(intentSegment.requirement.erc20Contract, owner);
        require(
            currentBalance >= uint256(requiredBalance),
            string.concat(
                "insufficient balance (required: ",
                Strings.toString(requiredBalance),
                ", current: ",
                Strings.toString(currentBalance),
                ")"
            )
        );
    }
}
