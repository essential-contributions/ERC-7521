// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {INonceManager} from "../interfaces/INonceManager.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {NonceManager} from "../core/NonceManager.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";

/**
 * Sequential Nonce Intent Standard core logic
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [uint256] nonce - the nonce
 */
abstract contract SequentialNonceCore {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateSequentialNonce(bytes calldata segmentData) internal pure {
        require(segmentData.length == 64, "Sequential Nonce data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeSequentialNonce(address intentSender, bytes calldata segmentData) internal {
        uint256 nonce = uint256(getSegmentWord(segmentData, 32));
        INonceManager nonceManager = INonceManager(msg.sender);

        uint192 key = uint192(nonce >> 64);
        uint64 next = uint64(nonceManager.getNonce(intentSender, key) + 1);
        require(uint64(nonce) == next, "Invalid nonce");
        nonceManager.setNonce(intentSender, key, next);
    }
}

/**
 * Sequential Nonce Intent Standard core logic
 */
abstract contract SequentialNonceManagerCore is NonceManager {
    /**
     * Validate intent segment structure (typically just formatting).
     */
    function _validateSequentialNonce(bytes calldata segmentData) internal pure {
        require(segmentData.length == 64, "Sequential Nonce data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     */
    function _executeSequentialNonce(address intentSender, bytes calldata segmentData) internal {
        uint256 nonce = uint256(getSegmentWord(segmentData, 32));

        uint192 key = uint192(nonce >> 64);
        uint64 next = uint64(_getNonce(intentSender, key) + 1);
        require(uint64(nonce) == next, "Invalid nonce");
        _setNonce(intentSender, key, next);
    }
}

/**
 * Sequential Nonce Intent Standard that can be deployed and registered to the entry point
 */
contract SequentialNonce is SequentialNonceCore, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        _validateSequentialNonce(segmentData);
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
        _executeSequentialNonce(intent.sender, intent.segments[segmentIndex]);
        return context;
    }
}

/**
 * Helper function to encode intent standard segment data.
 * @param standardId the entry point identifier for this standard
 * @param nonce the nonce
 * @return the fully encoded intent standard segment data
 */
function encodeSequentialNonceData(bytes32 standardId, uint256 nonce) pure returns (bytes memory) {
    return abi.encodePacked(standardId, nonce);
}
