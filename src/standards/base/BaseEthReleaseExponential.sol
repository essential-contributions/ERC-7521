// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseIntentStandard} from "../../interfaces/BaseIntentStandard.sol";
import {IIntentDelegate} from "../../interfaces/IIntentDelegate.sol";
import {UserIntent} from "../../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {EthReleaseDelegate} from "../delegates/EthReleaseDelegate.sol";
import {popFromCalldata} from "../utils/ContextData.sol";
import {getSegmentWord} from "../utils/SegmentData.sol";
import {
    evaluateExponentialCurve,
    encodeExponentialCurve1,
    encodeExponentialCurve2,
    encodeExponentialCurve3,
    encodeAsUint96,
    encodeAsUint64
} from "../utils/CurveCoder.sol";

/**
 * Eth Require with Exponential Curve Intent Standard
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [uint40]  startTime - start time of the curve (in seconds)
 *   [uint32]  deltaTime - amount of time from start until curve caps (in seconds)
 *   [uint96]  startAmount - starting amount
 *   [uint8]   startAmountMult - starting amount multiplier (final_amount = amount * (amountMult * 10))
 *   [uint64]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - delta amount multiplier (final_amount = amount * (amountMult * 10))
 *   [bytes1]  flags/exponent - evaluate backwards, negatives, exponent [fnnx eeee]
 */
contract BaseEthReleaseExponential is BaseIntentStandard, EthReleaseDelegate {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function _validateIntentSegment(bytes calldata segmentData) internal pure virtual override {
        require(segmentData.length != 64, "ETH Release Exponential data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return newContext to remember for further execution.
     */
    function _executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) internal virtual override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];

        //evaluate data
        bytes32 data = getSegmentWord(intent.intentData[segmentIndex], 32);
        int256 releaseAmount = evaluateExponentialCurve(data, solution.timestamp);

        //release
        address nextExecutingIntentSender = solution.intents[solution.getIntentIndex(executionIndex + 1)].sender;
        if (releaseAmount > 0) {
            bytes memory releaseEthDelegate = _encodeReleaseEth(nextExecutingIntentSender, uint256(releaseAmount));
            IIntentDelegate(address(intent.sender)).generalizedIntentDelegateCall(releaseEthDelegate);
        }

        //return context unchanged
        return context;
    }

    /**
     * Helper function to encode intent standard segment data.
     * @param standardId the entry point identifier for this standard
     * @param startTime start time of the curve (in seconds)
     * @param deltaTime amount of time from start until curve caps (in seconds)
     * @param startAmount starting amount
     * @param deltaAmount amount of change after each second
     * @param exponent the exponent order of the curve
     * @param backwards evaluate curve from right to left
     * @return the fully encoded intent standard segment data
     */
    function encodeData(
        bytes32 standardId,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards
    ) external pure returns (bytes memory) {
        bytes32 data = encodeExponentialCurve1(bytes32(0), startTime, deltaTime, exponent, backwards, false);
        {
            (uint96 adjStartAmount, uint8 startMult, bool startNegative) = encodeAsUint96(startAmount);
            data = encodeExponentialCurve2(data, adjStartAmount, startMult, startNegative);
        }
        {
            (uint64 adjDeltaAmount, uint8 deltaMult, bool deltaNegative) = encodeAsUint64(deltaAmount);
            data = encodeExponentialCurve3(data, adjDeltaAmount, deltaMult, deltaNegative);
        }
        return abi.encodePacked(standardId, bytes32(data));
    }
}
