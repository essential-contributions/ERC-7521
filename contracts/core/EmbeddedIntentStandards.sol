// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable private-vars-leading-underscore */

import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {Erc20RecordCore} from "../standards/Erc20Record.sol";
import {Erc20ReleaseCore} from "../standards/Erc20Release.sol";
import {Erc20RequireCore} from "../standards/Erc20Require.sol";
import {EthRecordCore} from "../standards/EthRecord.sol";
import {EthReleaseCore} from "../standards/EthRelease.sol";
import {EthRequireCore} from "../standards/EthRequire.sol";
import {SequentialNonceManagerCore} from "../standards/SequentialNonce.sol";
import {SimpleCallCore} from "../standards/SimpleCall.sol";
import {UserOperationCore} from "../standards/UserOperation.sol";

// embedded intent standard IDs
bytes32 constant SIMPLE_CALL_STD_ID = bytes32(uint256(0));
bytes32 constant ERC20_RECORD_STD_ID = bytes32(uint256(1));
bytes32 constant ERC20_RELEASE_STD_ID = bytes32(uint256(2));
bytes32 constant ERC20_REQUIRE_STD_ID = bytes32(uint256(3));
bytes32 constant ETH_RECORD_STD_ID = bytes32(uint256(4));
bytes32 constant ETH_RELEASE_STD_ID = bytes32(uint256(5));
bytes32 constant ETH_REQUIRE_STD_ID = bytes32(uint256(6));
bytes32 constant SEQUENTIAL_NONCE_STD_ID = bytes32(uint256(7));
bytes32 constant USER_OPERATION_STD_ID = bytes32(uint256(8));
uint256 constant NUM_EMBEDDED_STANDARDS = uint256(9);

abstract contract EmbeddedIntentStandards is
    SimpleCallCore,
    Erc20RecordCore,
    Erc20ReleaseCore,
    Erc20RequireCore,
    EthRecordCore,
    EthReleaseCore,
    EthRequireCore,
    SequentialNonceManagerCore,
    UserOperationCore
{
    using IntentSolutionLib for IntentSolution;

    /**
     * Handle an individual embedded intent segment.
     * @param standardId the segments standard ID.
     * @param solution the UserIntents solution.
     * @param intent the UserIntent.
     * @param segmentIndex the index of the segment in the intent.
     * @param executionIndex the index of all segments executing in the entire solution.
     * @param contextData the current intent processing context data.
     * @return contextData the updated context data.
     */
    function _handleEmbeddedIntentSegment(
        bytes32 standardId,
        IntentSolution calldata solution,
        UserIntent calldata intent,
        uint256 segmentIndex,
        uint256 executionIndex,
        bytes memory contextData
    ) internal returns (bytes memory) {
        if (standardId == SIMPLE_CALL_STD_ID) {
            _executeSimpleCall(intent.sender, intent.segments[segmentIndex]);
        } else if (standardId == ERC20_RECORD_STD_ID) {
            return _executeErc20Record(intent.sender, intent.segments[segmentIndex], contextData);
        } else if (standardId == ERC20_RELEASE_STD_ID) {
            _executeErc20Release(
                solution.timestamp,
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.segments[segmentIndex]
            );
        } else if (standardId == ERC20_REQUIRE_STD_ID) {
            return _executeErc20Require(solution.timestamp, intent.sender, intent.segments[segmentIndex], contextData);
        } else if (standardId == ETH_RECORD_STD_ID) {
            bytes1 flags = bytes1(0);
            if (intent.segments[segmentIndex].length == 33) flags = intent.segments[segmentIndex][32];
            return _executeEthRecord(intent.sender, flags, contextData);
        } else if (standardId == ETH_RELEASE_STD_ID) {
            _executeEthRelease(
                solution.timestamp,
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.segments[segmentIndex]
            );
        } else if (standardId == ETH_REQUIRE_STD_ID) {
            return _executeEthRequire(solution.timestamp, intent.sender, intent.segments[segmentIndex], contextData);
        } else if (standardId == SEQUENTIAL_NONCE_STD_ID) {
            _executeSequentialNonce(intent.sender, intent.segments[segmentIndex]);
        } else if (standardId == USER_OPERATION_STD_ID) {
            _executeUserOperation(intent.sender, intent.segments[segmentIndex]);
        }

        return contextData;
    }

    /**
     * Run validation for the given embedded intent segment.
     * @param standardId the segments standard ID.
     * @param segment the user intent segment to validate.
     */
    function _validateEmbeddedIntentSegment(bytes32 standardId, bytes calldata segment) internal pure {
        if (standardId == SIMPLE_CALL_STD_ID) {
            _validateSimpleCall(segment);
        } else if (standardId == ERC20_RECORD_STD_ID) {
            _validateErc20Record(segment);
        } else if (standardId == ERC20_RELEASE_STD_ID) {
            _validateErc20Release(segment);
        } else if (standardId == ERC20_REQUIRE_STD_ID) {
            _validateErc20Require(segment);
        } else if (standardId == ETH_RECORD_STD_ID) {
            _validateEthRecord(segment);
        } else if (standardId == ETH_RELEASE_STD_ID) {
            _validateEthRelease(segment);
        } else if (standardId == ETH_REQUIRE_STD_ID) {
            _validateEthRequire(segment);
        } else if (standardId == SEQUENTIAL_NONCE_STD_ID) {
            _validateSequentialNonce(segment);
        } else if (standardId == USER_OPERATION_STD_ID) {
            _validateUserOperation(segment);
        }
    }
}
