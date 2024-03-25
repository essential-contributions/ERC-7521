// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IAccountProxy} from "../interfaces/IAccountProxy.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {Erc20ReleaseDelegate} from "./delegates/Erc20ReleaseDelegate.sol";
import {popFromCalldata} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {
    evaluateCurve,
    encodeConstantCurve,
    encodeComplexCurve,
    isCurveRelative,
    isCurveProxy
} from "./utils/CurveCoder.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * ERC20 Release Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [address] token - the ERC20 token contract address
 *   [bytes1]  flags - evaluate backwards (flip), as proxy, exponent [f-p- eeee] [exponent: 0 = const, 1 = linear, >1 = exponential]
 *   [uint32]  startAmount - starting amount
 *   [uint8]   startAmountMult - amount multiplier (final_amount = amount * (amountMult * 10)) [first bit = negative]
 * --only for linear or exponential--
 *   [uint24]  deltaAmount - amount of change after each second
 *   [uint8]   deltaAmountMult - amount multiplier (final_amount = amount * (amountMult * 10)) [first bit = negative]
 *   [uint32]  startTime -  start time of the curve (in seconds)
 *   [uint16]  deltaTime - amount of time from start until curve caps (in seconds)
 */
abstract contract Erc20ReleaseCore is Erc20ReleaseDelegate {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateErc20Release(bytes calldata segmentData) internal pure {
        require(segmentData.length == 70 || segmentData.length == 80, "ERC-20 Release data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeErc20Release(
        uint256 timestamp,
        address intentSender,
        address nextExecutingIntentSender,
        bytes calldata segmentData
    ) internal {
        address token = address(uint160(uint256(getSegmentWord(segmentData, 32))));
        bytes16 curve = segmentData.length < 80
            ? bytes16(getSegmentWord(segmentData, 38) << (26 * 8))
            : bytes16(getSegmentWord(segmentData, 48) << (16 * 8));
        int256 releaseAmount = evaluateCurve(curve, timestamp);

        //release
        if (releaseAmount > 0) {
            address from = address(0);
            if (isCurveProxy(curve)) from = IAccountProxy(intentSender).proxyFor();
            bytes memory releaseEthDelegate =
                _encodeReleaseErc20(token, from, nextExecutingIntentSender, uint256(releaseAmount));
            IIntentDelegate(address(intentSender)).generalizedIntentDelegateCall(releaseEthDelegate);
        }
    }
}

/**
 * ERC20 Release Intent Standard that can be deployed and registered to the entry point
 */
contract Erc20Release is Erc20ReleaseCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateErc20Release(segmentData);
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
        _executeErc20Release(
            solution.timestamp,
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
 * @param token the ERC20 token contract address
 * @param amount amount required
 * @param isProxy curve is for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeErc20ReleaseData(bytes32 standardId, address token, int256 amount, bool isProxy)
    pure
    returns (bytes memory)
{
    bytes6 data = encodeConstantCurve(amount, false, isProxy);
    return abi.encodePacked(standardId, uint256(uint160(token)), data);
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param token the ERC20 token contract address
 * @param startTime start time of the curve (in seconds)
 * @param deltaTime amount of time from start until curve caps (in seconds)
 * @param startAmount starting amount
 * @param deltaAmount amount of change after each second
 * @param exponent the exponent order of the curve
 * @param backwards evaluate curve from right to left
 * @param isProxy curve is for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeErc20ReleaseComplexData(
    bytes32 standardId,
    address token,
    uint32 startTime,
    uint16 deltaTime,
    int256 startAmount,
    int256 deltaAmount,
    uint8 exponent,
    bool backwards,
    bool isProxy
) pure returns (bytes memory) {
    bytes16 data =
        encodeComplexCurve(startTime, deltaTime, startAmount, deltaAmount, exponent, backwards, false, isProxy);
    return abi.encodePacked(standardId, uint256(uint160(token)), data);
}
