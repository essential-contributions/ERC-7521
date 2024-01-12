// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IAccountProxy} from "../interfaces/IAccountProxy.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {pop} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {
    evaluateCurve,
    encodeConstantCurve,
    encodeComplexCurve,
    isCurveRelative,
    isCurveProxy
} from "./utils/CurveCoder.sol";

/**
 * Eth Require Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [bytes1]  flags - evaluate backwards (flip), relative, as proxy, exponent [frp- eeee] [exponent: 0 = const, 1 = linear, >1 = exponential]
 *   [uint32]  startAmount - starting amount
 *   [uint8]   startAmountMult - amount multiplier (final_amount = amount * (amountMult * 10)) [first bit = negative]
 * --only for linear or exponential--
 *   [uint24]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - amount multiplier (final_amount = amount * (amountMult * 10)) [first bit = negative]
 *   [uint32]  startTime -  start time of the curve (in seconds)
 *   [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
 */
abstract contract EthRequireCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateEthRequire(bytes calldata segmentData) internal pure {
        require(segmentData.length == 38 || segmentData.length == 48, "ETH Release data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeEthRequire(
        uint256 timestamp,
        address intentSender,
        bytes calldata segmentData,
        bytes memory context
    ) internal view returns (bytes memory newContext) {
        //evaluate data
        bytes16 curve = segmentData.length < 48
            ? bytes16(getSegmentWord(segmentData, 6) << (26 * 8))
            : bytes16(getSegmentWord(segmentData, 16) << (16 * 8));
        int256 requiredBalance = evaluateCurve(curve, timestamp);
        if (isCurveRelative(curve)) {
            //relative to previous balance
            bytes32 previousBalance;
            (newContext, previousBalance) = pop(context);
            requiredBalance = int256(uint256(previousBalance)) + requiredBalance;
        } else {
            //context data remains the same
            newContext = context;
        }

        // check requirement
        if (requiredBalance > 0) {
            address account = intentSender;
            if (isCurveProxy(curve)) account = IAccountProxy(intentSender).proxyFor();

            uint256 currentBalance = account.balance;
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
}

/**
 * Eth Require Intent Standard that can be deployed and registered to the entry point
 */
contract EthRequire is EthRequireCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateEthRequire(segmentData);
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return newContext to remember for further execution.
     */
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external view override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        return _executeEthRequire(solution.timestamp, intent.sender, intent.intentData[segmentIndex], context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param amount amount required
 * @param isRelative meant to be evaluated relatively
 * @param isProxy curve is for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeEthRequireData(bytes32 standardId, int256 amount, bool isRelative, bool isProxy)
    pure
    returns (bytes memory)
{
    bytes6 data = encodeConstantCurve(amount, isRelative, isProxy);
    return abi.encodePacked(standardId, data);
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
 * @param isRelative meant to be evaluated relatively
 * @param isProxy curve is for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeEthRequireComplexData(
    bytes32 standardId,
    uint32 startTime,
    uint16 deltaTime,
    int256 startAmount,
    int256 deltaAmount,
    uint8 exponent,
    bool backwards,
    bool isRelative,
    bool isProxy
) pure returns (bytes memory) {
    bytes16 data =
        encodeComplexCurve(startTime, deltaTime, startAmount, deltaAmount, exponent, backwards, isRelative, isProxy);
    return abi.encodePacked(standardId, data);
}
