// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {pop} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {
    evaluateConstantCurve, encodeConstantCurve, isConstantCurveRelative, encodeAsUint96
} from "./utils/CurveCoder.sol";

/**
 * Eth Require Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [uint96]  amount - amount required
 *   [uint8]   amountMult - amount multiplier (final_amount = amount << amountMult)
 *   [bytes1]  flags - negative, relative or absolute [nrxx xxxx]
 */
abstract contract EthRequireCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateEthRequire(bytes calldata segmentData) internal pure {
        require(segmentData.length != 46, "ETH Require data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeEthRequire(address intentSender, bytes calldata segmentData, bytes memory context)
        internal
        view
        returns (bytes memory newContext)
    {
        //evaluate data
        bytes32 curve = getSegmentWord(segmentData, 32);
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
            uint256 currentBalance = intentSender.balance;
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
 * Eth Release Intent Standard that can be deployed and registered to the entry point
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
        return _executeEthRequire(intent.sender, intent.intentData[segmentIndex], context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param amount amount required
 * @param isRelative meant to be evaluated relatively
 * @return the fully encoded intent standard segment data
 */
function encodeEthRequireData(bytes32 standardId, int256 amount, bool isRelative) pure returns (bytes memory) {
    (uint96 adjustedAmount, uint8 amountMult, bool amountNegative) = encodeAsUint96(amount);
    bytes32 data = encodeConstantCurve(uint96(adjustedAmount), amountMult, amountNegative, isRelative);
    return abi.encodePacked(standardId, bytes14(data));
}
