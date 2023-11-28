// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {INonceManager} from "../interfaces/INonceManager.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {getSegmentWord} from "./utils/SegmentData.sol";

/**
 * Sequential Nonce Intent Standard
 * @dev data
 *   [bytes32] standard - the intent standard identifier
 *   [uint256] nonce - the nonce
 */
contract SequentialNonce is IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {
        require(segmentData.length != 64, "Sequential Nonce data length invalid");
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution.
     */
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        uint256 nonce = uint256(getSegmentWord(intent.intentData[segmentIndex], 32));
        INonceManager nonceManager = INonceManager(msg.sender);

        uint192 key = uint192(nonce >> 64);
        uint64 seq = uint64(nonce);
        uint64 next = uint64(nonceManager.getNonce(intent.sender, key) + 1);
        require(seq == next, "Invalid nonce");
        nonceManager.setNonce(key, next);

        //return context unchanged
        return context;
    }

    /**
     * Helper function to encode intent standard segment data.
     * @param standardId the entry point identifier for this standard
     * @param nonce the nonce
     * @return the fully encoded intent standard segment data
     */
    function encodeData(bytes32 standardId, uint256 nonce) external pure returns (bytes memory) {
        return abi.encodePacked(standardId, nonce);
    }
}
