// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IntentSolutionLib, IntentSolution} from "../interfaces/IntentSolution.sol";
import {Erc20RecordCore} from "../standards/Erc20Record.sol";
import {Erc20ReleaseCore} from "../standards/Erc20Release.sol";
import {Erc20ReleaseExponentialCore} from "../standards/Erc20ReleaseExponential.sol";
import {Erc20ReleaseLinearCore} from "../standards/Erc20ReleaseLinear.sol";
import {Erc20RequireCore} from "../standards/Erc20Require.sol";
import {Erc20RequireExponentialCore} from "../standards/Erc20RequireExponential.sol";
import {Erc20RequireLinearCore} from "../standards/Erc20RequireLinear.sol";
import {EthRecordCore} from "../standards/EthRecord.sol";
import {EthReleaseCore} from "../standards/EthRelease.sol";
import {EthReleaseExponentialCore} from "../standards/EthReleaseExponential.sol";
import {EthReleaseLinearCore} from "../standards/EthReleaseLinear.sol";
import {EthRequireCore} from "../standards/EthRequire.sol";
import {EthRequireExponentialCore} from "../standards/EthRequireExponential.sol";
import {EthRequireLinearCore} from "../standards/EthRequireLinear.sol";
import {SequentialNonceManagerCore} from "../standards/SequentialNonce.sol";
import {SimpleCallCore} from "../standards/SimpleCall.sol";
import {UserOperationCore} from "../standards/UserOperation.sol";
import {getSegmentStandard} from "../standards/utils/SegmentData.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";

bytes32 constant SIMPLE_CALL_STD_ID = bytes32(uint256(0));
bytes32 constant ERC20_RECORD_STD_ID = bytes32(uint256(1));
bytes32 constant ERC20_RELEASE_STD_ID = bytes32(uint256(2));
bytes32 constant ERC20_RELEASE_EXPONENTIAL_STD_ID = bytes32(uint256(3));
bytes32 constant ERC20_RELEASE_LINEAR_STD_ID = bytes32(uint256(4));
bytes32 constant ERC20_REQUIRE_STD_ID = bytes32(uint256(5));
bytes32 constant ERC20_REQUIRE_EXPONENTIAL_STD_ID = bytes32(uint256(6));
bytes32 constant ERC20_REQUIRE_LINEAR_STD_ID = bytes32(uint256(7));
bytes32 constant ETH_RECORD_STD_ID = bytes32(uint256(8));
bytes32 constant ETH_RELEASE_STD_ID = bytes32(uint256(9));
bytes32 constant ETH_RELEASE_EXPONENTIAL_STD_ID = bytes32(uint256(10));
bytes32 constant ETH_RELEASE_LINEAR_STD_ID = bytes32(uint256(11));
bytes32 constant ETH_REQUIRE_STD_ID = bytes32(uint256(12));
bytes32 constant ETH_REQUIRE_EXPONENTIAL_STD_ID = bytes32(uint256(13));
bytes32 constant ETH_REQUIRE_LINEAR_STD_ID = bytes32(uint256(14));
bytes32 constant SEQUENTIAL_NONCE_STD_ID = bytes32(uint256(15));
bytes32 constant USER_OPERATION_STD_ID = bytes32(uint256(16));
uint256 constant NUM_EMBEDDED_STANDARDS = uint256(17);

abstract contract EmbeddedIntentStandards is
    SimpleCallCore,
    Erc20RecordCore,
    Erc20ReleaseCore,
    Erc20ReleaseExponentialCore,
    Erc20ReleaseLinearCore,
    Erc20RequireCore,
    Erc20RequireExponentialCore,
    Erc20RequireLinearCore,
    EthRecordCore,
    EthReleaseCore,
    EthReleaseExponentialCore,
    EthReleaseLinearCore,
    EthRequireCore,
    EthRequireExponentialCore,
    EthRequireLinearCore,
    SequentialNonceManagerCore,
    UserOperationCore
{
    using IntentSolutionLib for IntentSolution;

    function isEmbeddedIntentStandard(bytes32 standardId) public pure returns (bool) {
        return uint256(standardId) < NUM_EMBEDDED_STANDARDS;
    }

    /**
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function _validateEmbeddedIntentSegment(bytes calldata segmentData) internal pure {
        bytes32 standardId = getSegmentStandard(segmentData);
        if (standardId == SIMPLE_CALL_STD_ID) {
            _validateSimpleCall(segmentData);
        } else if (standardId == ERC20_RECORD_STD_ID) {
            _validateErc20Record(segmentData);
        } else if (standardId == ERC20_RELEASE_STD_ID) {
            _validateErc20Release(segmentData);
        } else if (standardId == ERC20_RELEASE_EXPONENTIAL_STD_ID) {
            _validateErc20ReleaseExponential(segmentData);
        } else if (standardId == ERC20_RELEASE_LINEAR_STD_ID) {
            _validateErc20ReleaseLinear(segmentData);
        } else if (standardId == ERC20_REQUIRE_STD_ID) {
            _validateErc20Require(segmentData);
        } else if (standardId == ERC20_REQUIRE_EXPONENTIAL_STD_ID) {
            _validateErc20RequireExponential(segmentData);
        } else if (standardId == ERC20_REQUIRE_LINEAR_STD_ID) {
            _validateErc20RequireLinear(segmentData);
        } else if (standardId == ETH_RECORD_STD_ID) {
            _validateEthRecord(segmentData);
        } else if (standardId == ETH_RELEASE_STD_ID) {
            _validateEthRelease(segmentData);
        } else if (standardId == ETH_RELEASE_EXPONENTIAL_STD_ID) {
            _validateEthReleaseExponential(segmentData);
        } else if (standardId == ETH_RELEASE_LINEAR_STD_ID) {
            _validateEthReleaseLinear(segmentData);
        } else if (standardId == ETH_REQUIRE_STD_ID) {
            _validateEthRequire(segmentData);
        } else if (standardId == ETH_REQUIRE_EXPONENTIAL_STD_ID) {
            _validateEthRequireExponential(segmentData);
        } else if (standardId == ETH_REQUIRE_LINEAR_STD_ID) {
            _validateEthRequireLinear(segmentData);
        } else if (standardId == SEQUENTIAL_NONCE_STD_ID) {
            _validateSequentialNonce(segmentData);
        } else if (standardId == USER_OPERATION_STD_ID) {
            _validateUserOperation(segmentData);
        } else {
            revert("Cannot validate invalid standard");
        }
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution.
     */
    function _executeEmbeddedIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) internal returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        bytes32 standardId = getSegmentStandard(intent.intentData[segmentIndex]);
        if (standardId == SIMPLE_CALL_STD_ID) {
            _executeSimpleCall(intent.sender, intent.intentData[segmentIndex]);
        } else if (standardId == ERC20_RECORD_STD_ID) {
            return _executeErc20Record(intent.sender, intent.intentData[segmentIndex], context);
        } else if (standardId == ERC20_RELEASE_STD_ID) {
            _executeErc20Release(
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.intentData[segmentIndex]
            );
        } else if (standardId == ERC20_RELEASE_EXPONENTIAL_STD_ID) {
            _executeErc20ReleaseExponential(
                solution.timestamp,
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.intentData[segmentIndex]
            );
        } else if (standardId == ERC20_RELEASE_LINEAR_STD_ID) {
            _executeErc20ReleaseLinear(
                solution.timestamp,
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.intentData[segmentIndex]
            );
        } else if (standardId == ERC20_REQUIRE_STD_ID) {
            return _executeErc20Require(intent.sender, intent.intentData[segmentIndex], context);
        } else if (standardId == ERC20_REQUIRE_EXPONENTIAL_STD_ID) {
            return _executeErc20RequireExponential(
                solution.timestamp, intent.sender, intent.intentData[segmentIndex], context
            );
        } else if (standardId == ERC20_REQUIRE_LINEAR_STD_ID) {
            return
                _executeErc20RequireLinear(solution.timestamp, intent.sender, intent.intentData[segmentIndex], context);
        } else if (standardId == ETH_RECORD_STD_ID) {
            return _executeEthRecord(intent.sender, context);
        } else if (standardId == ETH_RELEASE_STD_ID) {
            _executeEthRelease(
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.intentData[segmentIndex]
            );
        } else if (standardId == ETH_RELEASE_EXPONENTIAL_STD_ID) {
            _executeEthReleaseExponential(
                solution.timestamp,
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.intentData[segmentIndex]
            );
        } else if (standardId == ETH_RELEASE_LINEAR_STD_ID) {
            _executeEthReleaseLinear(
                solution.timestamp,
                intent.sender,
                solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                intent.intentData[segmentIndex]
            );
        } else if (standardId == ETH_REQUIRE_STD_ID) {
            return _executeEthRequire(intent.sender, intent.intentData[segmentIndex], context);
        } else if (standardId == ETH_REQUIRE_EXPONENTIAL_STD_ID) {
            return _executeEthRequireExponential(
                solution.timestamp, intent.sender, intent.intentData[segmentIndex], context
            );
        } else if (standardId == ETH_REQUIRE_LINEAR_STD_ID) {
            return _executeEthRequireLinear(solution.timestamp, intent.sender, intent.intentData[segmentIndex], context);
        } else if (standardId == SEQUENTIAL_NONCE_STD_ID) {
            _executeSequentialNonce(intent.sender, intent.intentData[segmentIndex]);
        } else if (standardId == USER_OPERATION_STD_ID) {
            _executeUserOperation(intent.sender, intent.intentData[segmentIndex]);
        } else {
            revert("Cannot execute invalid standard");
        }

        return context;
    }
}
