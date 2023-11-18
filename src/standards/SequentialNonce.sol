// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/* solhint-disable private-vars-leading-underscore */

import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {INonceManager} from "../interfaces/INonceManager.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";

/**
 * Sequential Nonce Segment struct
 * @param standard intent standard id for segment.
 * @param nonce the nonce.
 */
struct SequentialNonceSegment {
    bytes32 standard;
    uint256 nonce;
}

contract SequentialNonce is IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {}

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
        bytes memory context
    ) external returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        SequentialNonceSegment calldata segment = parseIntentSegment(intent.intentData[segmentIndex]);
        INonceManager nonceManager = INonceManager(msg.sender);

        uint192 key = uint192(segment.nonce >> 64);
        uint64 seq = uint64(segment.nonce);
        uint64 next = uint64(nonceManager.getNonce(intent.sender, key) + 1);
        require(seq == next, "Invalid nonce");
        nonceManager.setNonce(key, next);

        return context;
    }

    function parseIntentSegment(bytes calldata segmentData)
        internal
        pure
        returns (SequentialNonceSegment calldata segment)
    {
        assembly {
            segment := segmentData.offset
        }
    }
}
