// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IAccountProxy} from "../interfaces/IAccountProxy.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {push} from "./utils/ContextData.sol";

/**
 * Eth Record Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [bytes1]  flags - (optional) as proxy [---- ---p]
 */
abstract contract EthRecordCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateEthRecord(bytes calldata segmentData) internal pure {
        require(segmentData.length == 32 || segmentData.length == 33, "ETH Record data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeEthRecord(address intentSender, bytes1 flags, bytes memory context)
        internal
        view
        returns (bytes memory)
    {
        address account = intentSender;
        if (flags > 0) account = IAccountProxy(intentSender).proxyFor();

        //push current eth balance to the context data
        return push(context, bytes32(account.balance));
    }
}

/**
 * Eth Record Intent Standard that can be deployed and registered to the entry point
 */
contract EthRecord is EthRecordCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateEthRecord(segmentData);
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
        bytes1 flags = bytes1(0);
        if (intent.segments[segmentIndex].length == 33) flags = intent.segments[segmentIndex][32];
        return _executeEthRecord(intent.sender, flags, context);
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param isProxy for an account other than the original sender
 * @return the fully encoded intent standard segment data
 */
function encodeEthRecordData(bytes32 standardId, bool isProxy) pure returns (bytes memory) {
    if (isProxy) return abi.encodePacked(standardId, uint8(1));
    return abi.encodePacked(standardId);
}
