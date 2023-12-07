// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {EthReleaseDelegate} from "./delegates/EthReleaseDelegate.sol";
import {popFromCalldata} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {evaluateConstantCurve, encodeConstantCurve, encodeAsUint96} from "./utils/CurveCoder.sol";

/**
 * Eth Release Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [uint96]  amount - amount required
 *   [uint8]   amountMult - amount multiplier (final_amount = amount << amountMult)
 *   [bytes1]  flags - negative [nxxx xxxx]
 */
abstract contract EthReleaseCore is EthReleaseDelegate {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateEthRelease(bytes calldata segmentData) internal pure {
        require(segmentData.length != 46, "ETH Release data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeEthRelease(address intentSender, address nextExecutingIntentSender, bytes calldata segmentData)
        internal
    {
        //evaluate data
        bytes32 curve = getSegmentWord(segmentData, 32);
        int256 releaseAmount = evaluateConstantCurve(curve);

        //release
        if (releaseAmount > 0) {
            bytes memory releaseEthDelegate = _encodeReleaseEth(nextExecutingIntentSender, uint256(releaseAmount));
            IIntentDelegate(address(intentSender)).generalizedIntentDelegateCall(releaseEthDelegate);
        }
    }
}

/**
 * Eth Release Intent Standard that can be deployed and registered to the entry point
 */
contract EthRelease is EthReleaseCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateEthRelease(segmentData);
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
    ) external override returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        _executeEthRelease(
            intent.sender,
            solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
            intent.intentData[segmentIndex]
        );
        return context;
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param amount amount required
 * @return the fully encoded intent standard segment data
 */
function encodeEthReleaseData(bytes32 standardId, int256 amount) pure returns (bytes memory) {
    (uint96 adjustedAmount, uint8 amountMult, bool amountNegative) = encodeAsUint96(amount);
    bytes32 data = encodeConstantCurve(uint96(adjustedAmount), amountMult, amountNegative, false);
    return abi.encodePacked(standardId, bytes14(data));
}
