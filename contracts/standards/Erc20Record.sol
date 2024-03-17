// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IAccountProxy} from "../interfaces/IAccountProxy.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {push} from "./utils/ContextData.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * ERC20 Record Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [address] token - the ERC20 token contract address
 *   [bytes1]  flags - (optional) as proxy [---- ---p]
 */
abstract contract Erc20RecordCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateErc20Record(bytes calldata segmentData) internal pure {
        require(segmentData.length == 64 || segmentData.length == 65, "ERC-20 Record data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeErc20Record(address intentSender, bytes calldata segmentData, bytes memory context)
        internal
        view
        returns (bytes memory)
    {
        address token = address(uint160(uint256(getSegmentWord(segmentData, 32))));
        address account = intentSender;
        if (segmentData.length == 65 && uint8(segmentData[64]) > 0) {
            account = IAccountProxy(intentSender).proxyFor();
        }

        //push current eth balance to the context data
        uint256 balance = IERC20(token).balanceOf(account);
        return push(context, bytes32(balance));
    }
}

/**
 * ERC20 Record Intent Standard that can be deployed and registered to the entry point
 */
contract Erc20Record is Erc20RecordCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateErc20Record(segmentData);
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
        return _executeErc20Record(intent.sender, intent.intentData[segmentIndex], context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param token the token contract address
 * @param isProxy for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeErc20RecordData(bytes32 standardId, address token, bool isProxy) pure returns (bytes memory) {
    if (isProxy) return abi.encodePacked(standardId, uint256(uint160(token)), uint8(1));
    return abi.encodePacked(standardId, uint256(uint160(token)));
}
