// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {pop} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {
    evaluateConstantCurve, encodeConstantCurve, isConstantCurveRelative, encodeAsUint96
} from "./utils/CurveCoder.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * ERC20 Require Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [address] token - the ERC20 token contract address
 *   [uint96]  amount - amount required
 *   [uint8]   amountMult - amount multiplier (final_amount = amount << amountMult)
 *   [bytes1]  flags - negative, relative or absolute [nrxx xxxx]
 */
abstract contract Erc20RequireCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateErc20Require(bytes calldata segmentData) internal pure {
        require(segmentData.length != 66, "ERC-20 Require data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeErc20Require(address intentSender, bytes calldata segmentData, bytes memory context)
        internal
        view
        returns (bytes memory newContext)
    {
        address token = address(uint160(uint256(getSegmentWord(segmentData, 20))));

        //evaluate data
        bytes32 curve = getSegmentWord(segmentData, 34) << 144;
        int256 requiredBalance = evaluateConstantCurve(curve);
        if (isConstantCurveRelative(curve)) {
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
 * ERC20 Require Intent Standard core logic that can be deployed and registered to the entry point
 */
contract Erc20Require is Erc20RequireCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateErc20Require(segmentData);
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
        return _executeErc20Require(intent.sender, intent.intentData[segmentIndex], context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param token the ERC20 token contract address
 * @param amount amount required
 * @param isRelative meant to be evaluated relatively
 * @return the fully encoded intent standard segment data
 */
function encodeErc20RequireData(bytes32 standardId, address token, int256 amount, bool isRelative)
    pure
    returns (bytes memory)
{
    (uint96 adjustedAmount, uint8 amountMult, bool amountNegative) = encodeAsUint96(amount);
    bytes32 data = encodeConstantCurve(uint96(adjustedAmount), amountMult, amountNegative, isRelative);
    return abi.encodePacked(standardId, token, bytes14(data));
}
