// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {pop} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {
    evaluateLinearCurve,
    encodeLinearCurve1,
    encodeLinearCurve2,
    isLinearCurveRelative,
    encodeAsUint96,
    encodeAsUint64
} from "./utils/CurveCoder.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * ERC20 Require with Linear Curve Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [address] token - the ERC20 token contract address
 *   [uint40]  startTime - start time of the curve (in seconds)
 *   [uint32]  deltaTime - amount of time from start until curve caps (in seconds)
 *   [uint96]  startAmount - starting amount
 *   [uint8]   startAmountMult - starting amount multiplier (final_amount = amount << amountMult)
 *   [uint64]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - delta amount multiplier (final_amount = amount << amountMult)
 *   [bytes1]  flags - negatives, relative or absolute [nnrx xxxx]
 */
abstract contract Erc20RequireLinearCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateErc20RequireLinear(bytes calldata segmentData) internal pure {
        require(segmentData.length != 84, "ERC-20 Require Linear data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeErc20RequireLinear(
        uint256 timestamp,
        address intentSender,
        bytes calldata segmentData,
        bytes memory context
    ) internal view returns (bytes memory newContext) {
        address token = address(uint160(uint256(getSegmentWord(segmentData, 20))));

        //evaluate data
        bytes32 curve = getSegmentWord(segmentData, 52);
        int256 requiredBalance = evaluateLinearCurve(curve, timestamp);
        if (isLinearCurveRelative(curve)) {
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
            uint256 currentBalance = IERC20(token).balanceOf(intentSender);
            require(
                currentBalance >= uint256(requiredBalance),
                string.concat(
                    "insufficient token balance (token: ",
                    Strings.toHexString(token),
                    ", required: ",
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
 * ERC20 Require with Linear Curve Intent Standard that can be deployed and registered to the entry point
 */
contract Erc20RequireLinear is Erc20RequireLinearCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateErc20RequireLinear(segmentData);
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
        return _executeErc20RequireLinear(solution.timestamp, intent.sender, intent.intentData[segmentIndex], context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param token the ERC20 token contract address
 * @param startTime start time of the curve (in seconds)
 * @param deltaTime amount of time from start until curve caps (in seconds)
 * @param startAmount starting amount
 * @param deltaAmount amount of change after each second
 * @param isRelative meant to be evaluated relatively
 * @return the fully encoded intent standard segment data
 */
function encodeErc20RequireLinearData(
    bytes32 standardId,
    address token,
    uint40 startTime,
    uint32 deltaTime,
    int256 startAmount,
    int256 deltaAmount,
    bool isRelative
) pure returns (bytes memory) {
    bytes32 data;
    {
        (uint96 adjustedStartAmount, uint8 startMult, bool startNegative) = encodeAsUint96(startAmount);
        data = encodeLinearCurve1(data, startTime, deltaTime, adjustedStartAmount, startMult, startNegative);
    }
    {
        (uint64 adjustedDeltaAmount, uint8 deltaMult, bool deltaNegative) = encodeAsUint64(deltaAmount);
        data = encodeLinearCurve2(data, adjustedDeltaAmount, deltaMult, deltaNegative, isRelative);
    }
    return abi.encodePacked(standardId, token, bytes32(data));
}
