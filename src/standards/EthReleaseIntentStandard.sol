// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {EthCurve, isRelativeEvaluation, validate, evaluate} from "../utils/curves/EthCurve.sol";
import {EthReleaseIntentDelegate} from "./delegates/EthReleaseIntentDelegate.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {EntryPointTruster} from "../core/EntryPointTruster.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * Eth Release Intent Segment struct
 * @param release release curve.
 */
struct EthReleaseIntentSegment {
    EthCurve release;
}

contract EthReleaseIntentStandard is EntryPointTruster, IIntentStandard, EthReleaseIntentDelegate {
    using IntentSolutionLib for IntentSolution;
    using RevertReason for bytes;

    /**
     * Basic state and constants.
     */
    IEntryPoint private immutable _entryPoint;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Contract constructor.
     * @param entryPointContract the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPointContract) EthReleaseIntentDelegate() {
        _entryPoint = entryPointContract;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function standardId() public view returns (bytes32) {
        return _entryPoint.getIntentStandardId(this);
    }

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

    /**
     * Verifies the intent standard is for a given entry point contract (required for registration on the entry point).
     * @param entryPointContract the entry point contract.
     * @return flag indicating if the intent standard is for the given entry point.
     */
    function isIntentStandardForEntryPoint(IEntryPoint entryPointContract) external view override returns (bool) {
        return entryPointContract == _entryPoint;
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
}
