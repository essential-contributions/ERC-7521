// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {IntentStandardRegistry} from "./IntentStandardRegistry.sol";
import {NonceManager} from "./NonceManager.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {getSegmentStandard} from "../standards/utils/SegmentData.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

// embedded intent standards
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

contract EntryPoint is
    IEntryPoint,
    NonceManager,
    IntentStandardRegistry,
    ReentrancyGuard,
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
    using UserIntentLib for UserIntent;
    using RevertReason for bytes;

    // data limits
    uint256 private constant CONTEXT_DATA_MAX_LEN = 2048;

    // flag for applications to check current context of execution
    bytes32 private _executionState;
    bytes32 private constant EX_STATE_NOT_ACTIVE = bytes32(0);

    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     * @param signatureAggregator the allowed signature aggregator.
     * @param validatedIntents the intents that were validated with the signature aggregator.
     */
    function _handleIntents(IntentSolution calldata solution, IAggregator signatureAggregator, bytes32 validatedIntents)
        private
        nonReentrant
    {
        uint256 intsLen = solution.intents.length;
        require(intsLen > 0, "AA70 no intents");
        require(intsLen <= 32, "AA72 too many intents");
        require(solution.getTimestamp() > 0, "AA71 invalid timestamp");

        unchecked {
            // validate intents
            for (uint256 i = 0; i < intsLen; i++) {
                UserIntent calldata intent = solution.intents[i];
                bytes32 intentHash = _generateUserIntentHash(intent);
                uint256 numSegments = intent.intentData.length;
                if (numSegments > 256) {
                    revert FailedIntent(i, 0, string.concat("AA63 too many segments"));
                }
                if (intent.sender != address(0) && numSegments > 0) {
                    _validateUserIntentWithAccount(intent, intentHash, i, signatureAggregator, validatedIntents);
                    emit UserIntentEvent(intentHash, intent.sender, msg.sender);
                }
            }

            // execute solution
            bytes[] memory contextData = new bytes[](solution.intents.length);
            uint256 segmentIndexes = 0x0000000000000000000000000000000000000000000000000000000000000000;
            uint256 stillNeedToExecute =
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff >> (256 - intsLen);
            uint256 executionIndex = 0;

            // loop through the order specified by the solution
            uint256 orderLen = solution.order.length;
            for (; executionIndex < orderLen; executionIndex++) {
                uint256 intentIndex = solution.order[executionIndex];
                uint256 shift = intentIndex * 8;
                uint256 segmentIndex = (segmentIndexes >> shift) & 0xff;
                uint256 numSegments = solution.intents[intentIndex].intentData.length;

                if (segmentIndex < numSegments) {
                    contextData[intentIndex] = _handleIntentSegment(
                        solution, intentIndex, segmentIndex, executionIndex, contextData[intentIndex]
                    );

                    // keep track of what segments have been executed and if there are any remaining
                    segmentIndex++;
                    segmentIndexes = segmentIndexes & ~(0xff << shift);
                    segmentIndexes = segmentIndexes | (segmentIndex << shift);
                    if (segmentIndex >= numSegments) {
                        stillNeedToExecute = stillNeedToExecute & ~(0x01 << intentIndex);
                    }
                } else if (segmentIndex == 0) {
                    stillNeedToExecute = stillNeedToExecute & ~(0x01 << intentIndex);
                }
            }

            // require all segments to have executed
            if (stillNeedToExecute != 0x0000000000000000000000000000000000000000000000000000000000000000) {
                uint256 intentIndex = 0;
                for (; intentIndex < intsLen; intentIndex++) {
                    if (stillNeedToExecute & (0x01 << intentIndex) > 0) break;
                }
                uint256 segmentIndex = (segmentIndexes >> (intentIndex * 8)) & 0xff;
                revert FailedIntent(intentIndex, segmentIndex, string.concat("AA69 not fully executed"));
            }

            // no longer executing
            _executionState = EX_STATE_NOT_ACTIVE;
        } //unchecked
    }

    /**
     * Handle an individual intent segment.
     * @dev about 800 gas can be saved by embedding this into _handleIntents, but breaks coverage
     * @param solution the UserIntents solution.
     * @param intentIndex the index of the intent.
     * @param segmentIndex the index of the segment in the intent.
     * @param executionIndex the index of all segments executing in the entire solution.
     * @param contextData the current intent processing context data.
     * @return contextData the updated context data.
     */
    function _handleIntentSegment(
        IntentSolution calldata solution,
        uint256 intentIndex,
        uint256 segmentIndex,
        uint256 executionIndex,
        bytes memory contextData
    ) private returns (bytes memory) {
        UserIntent calldata intent = solution.intents[intentIndex];
        if (intent.sender != address(0) && intent.intentData.length > 0) {
            bytes32 standardId = getSegmentStandard(intent.intentData[segmentIndex]);

            // check if this is an embedded standard
            if (uint256(standardId) < NUM_EMBEDDED_STANDARDS) {
                _executionState = keccak256(abi.encodePacked(intent.sender, address(this)));
                if (standardId == SIMPLE_CALL_STD_ID) {
                    _executeSimpleCall(intent.sender, intent.intentData[segmentIndex]);
                } else if (standardId == ERC20_RECORD_STD_ID) {
                    return _executeErc20Record(intent.sender, intent.intentData[segmentIndex], contextData);
                } else if (standardId == ERC20_RELEASE_STD_ID) {
                    _executeErc20Release(
                        solution.timestamp,
                        intent.sender,
                        solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                        intent.intentData[segmentIndex]
                    );
                } else if (standardId == ERC20_REQUIRE_STD_ID) {
                    return _executeErc20Require(
                        solution.timestamp, intent.sender, intent.intentData[segmentIndex], contextData
                    );
                } else if (standardId == ETH_RECORD_STD_ID) {
                    bytes1 flags = bytes1(0);
                    if (intent.intentData[segmentIndex].length == 33) flags = intent.intentData[segmentIndex][32];
                    return _executeEthRecord(intent.sender, flags, contextData);
                } else if (standardId == ETH_RELEASE_STD_ID) {
                    _executeEthRelease(
                        solution.timestamp,
                        intent.sender,
                        solution.intents[solution.getIntentIndex(executionIndex + 1)].sender,
                        intent.intentData[segmentIndex]
                    );
                } else if (standardId == ETH_REQUIRE_STD_ID) {
                    return _executeEthRequire(
                        solution.timestamp, intent.sender, intent.intentData[segmentIndex], contextData
                    );
                } else if (standardId == SEQUENTIAL_NONCE_STD_ID) {
                    _executeSequentialNonce(intent.sender, intent.intentData[segmentIndex]);
                } else if (standardId == USER_OPERATION_STD_ID) {
                    _executeUserOperation(intent.sender, intent.intentData[segmentIndex]);
                } else {
                    revert FailedIntent(intentIndex, segmentIndex, "AA82 unknown standard");
                }
            } else {
                // execute as a registered standard
                IIntentStandard intentStandard = _registeredStandards[standardId];
                if (intentStandard == IIntentStandard(address(0))) {
                    revert FailedIntent(intentIndex, segmentIndex, "AA82 unknown standard");
                }
                _executionState = keccak256(abi.encodePacked(intent.sender, address(intentStandard)));
                bool success = Exec.call(
                    address(intentStandard),
                    0,
                    abi.encodeWithSelector(
                        IIntentStandard.executeIntentSegment.selector,
                        solution,
                        executionIndex,
                        segmentIndex,
                        contextData
                    ),
                    gasleft()
                );
                if (success) {
                    if (Exec.getReturnDataSize() > CONTEXT_DATA_MAX_LEN) {
                        revert FailedIntent(intentIndex, segmentIndex, "AA60 invalid execution context");
                    }
                    return Exec.getReturnData(0x40, CONTEXT_DATA_MAX_LEN);
                } else {
                    bytes memory reason =
                        Exec.getReturnData(Exec.REVERT_REASON_START_OFFSET, Exec.REVERT_REASON_MAX_LEN);
                    if (reason.length > 0) {
                        revert FailedIntent(
                            intentIndex,
                            segmentIndex,
                            string.concat("AA61 execution failed: ", string(reason.revertReasonWithoutPadding()))
                        );
                    }
                    revert FailedIntent(intentIndex, segmentIndex, "AA61 execution failed (or OOG)");
                }
            }
        }
        return contextData;
    }

    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     */
    function handleIntents(IntentSolution calldata solution) external {
        _handleIntents(solution, IAggregator(address(0)), bytes32(0));
    }

    /**
     * Execute a batch of UserIntents using multiple solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleIntentsMulti(IntentSolution[] calldata solutions) external {
        // loop through solutions and solve
        uint256 solsLen = solutions.length;
        for (uint256 i = 0; i < solsLen; i++) {
            _handleIntents(solutions[i], IAggregator(address(0)), bytes32(0));
        }
    }

    /**
     * Execute a batch of UserIntents with an aggregated signature.
     * @param solutions list of solutions to execute for intents.
     * @param aggregator address of aggregator.
     * @param intentsToAggregate bit field signaling which intents are part of the aggregated signature.
     * @param signature aggregated signature.
     */
    function handleIntentsAggregated(
        IntentSolution[] calldata solutions,
        IAggregator aggregator,
        bytes32 intentsToAggregate,
        bytes calldata signature
    ) external {
        require(address(aggregator) != address(0), "AA96 invalid aggregator");

        // get number of intents
        uint256 solsLen = solutions.length;
        uint256 totalIntents = 0;
        unchecked {
            for (uint256 i = 0; i < solsLen; i++) {
                totalIntents += solutions[0].intents.length;
            }
        }
        uint256 aggregatedIntentTotal = 0;
        for (uint256 i = 0; i < totalIntents; i++) {
            if ((uint256(intentsToAggregate) & (1 << i)) > 0) aggregatedIntentTotal++;
        }

        // validate aggregated intent signature
        UserIntent[] memory aggregatedIntents = new UserIntent[](aggregatedIntentTotal);
        for (uint256 i = 0; i < solsLen; i++) {
            for (uint256 j = 0; j < solutions[0].intents.length; j++) {}
        }
        aggregator.validateSignatures(aggregatedIntents, signature);

        // loop through solutions and solve
        for (uint256 i = 0; i < solsLen; i++) {
            _handleIntents(solutions[i], aggregator, intentsToAggregate);
            intentsToAggregate = intentsToAggregate << solutions[i].intents.length;
        }
    }

    /**
     * Run validation for the given intent.
     * @dev This method is view only.
     * @param intent the user intent to validate.
     */
    function validateIntent(UserIntent calldata intent) external view {
        // make sure sender is a deployed contract
        if (intent.sender.code.length == 0) {
            revert FailedIntent(0, 0, "AA20 account not deployed");
        }

        // validate intent standards are recognized and formatted correctly
        for (uint256 i = 0; i < intent.intentData.length; i++) {
            bytes32 standardId = getSegmentStandard(intent.intentData[i]);
            // validate the intent segment itself
            if (uint256(standardId) < NUM_EMBEDDED_STANDARDS) {
                if (standardId == SIMPLE_CALL_STD_ID) {
                    _validateSimpleCall(intent.intentData[i]);
                } else if (standardId == ERC20_RECORD_STD_ID) {
                    _validateErc20Record(intent.intentData[i]);
                } else if (standardId == ERC20_RELEASE_STD_ID) {
                    _validateErc20Release(intent.intentData[i]);
                } else if (standardId == ERC20_REQUIRE_STD_ID) {
                    _validateErc20Require(intent.intentData[i]);
                } else if (standardId == ETH_RECORD_STD_ID) {
                    _validateEthRecord(intent.intentData[i]);
                } else if (standardId == ETH_RELEASE_STD_ID) {
                    _validateEthRelease(intent.intentData[i]);
                } else if (standardId == ETH_REQUIRE_STD_ID) {
                    _validateEthRequire(intent.intentData[i]);
                } else if (standardId == SEQUENTIAL_NONCE_STD_ID) {
                    _validateSequentialNonce(intent.intentData[i]);
                } else if (standardId == USER_OPERATION_STD_ID) {
                    _validateUserOperation(intent.intentData[i]);
                } else {
                    revert("Cannot validate invalid standard");
                }
            } else {
                IIntentStandard standard = _registeredStandards[standardId];
                if (standard == IIntentStandard(address(0))) {
                    revert FailedIntent(0, i, "AA82 unknown standard");
                }

                // validate the intent segment itself
                try standard.validateIntentSegment(intent.intentData[i]) {}
                catch Error(string memory revertReason) {
                    revert FailedIntent(0, i, string.concat("AA62 reverted: ", revertReason));
                } catch {
                    revert FailedIntent(0, i, "AA62 reverted (or OOG)");
                }
            }
        }

        // validate signature
        bytes32 intentHash = _generateUserIntentHash(intent);
        _validateUserIntentWithAccount(intent, intentHash, 0, IAggregator(address(0)), bytes32(0));
    }

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the intent (except the signature), the entrypoint and the chainid.
     */
    function getUserIntentHash(UserIntent calldata intent) external view returns (bytes32) {
        return _generateUserIntentHash(intent);
    }

    /**
     * returns true if the given standard is currently executing an intent segment for the msg.sender.
     */
    function verifyExecutingIntentSegmentForStandard(IIntentStandard intentStandard) external view returns (bool) {
        return _executionState == keccak256(abi.encodePacked(msg.sender, address(intentStandard)));
    }

    /**
     * Manually set the nonce of the sender.
     * @dev this method should only be allowed to be called by the currently executing intent standard contract
     */
    function setNonce(address sender, uint256 key, uint256 nonce) external override {
        require(_executionState == keccak256(abi.encodePacked(sender, msg.sender)), "Invalid nonce access");
        _setNonce(sender, key, nonce);
    }

    /**
     * Validate user intent.
     * @param intent the user intent to validate.
     * @param intentHash hash of the user's intent data.
     * @param intentIndex the index of this intent.
     * @param signatureAggregator the allowed signature aggregator.
     * @param validatedIntents the intents that were validated with the signature aggregator.
     */
    function _validateUserIntentWithAccount(
        UserIntent calldata intent,
        bytes32 intentHash,
        uint256 intentIndex,
        IAggregator signatureAggregator,
        bytes32 validatedIntents
    ) private view {
        // validate intent with account
        try IAccount(intent.sender).validateUserIntent(intent, intentHash) returns (IAggregator aggregator) {
            //check if intent is to be verified by aggregator
            if (aggregator != IAggregator(address(0))) {
                if (aggregator != signatureAggregator) {
                    revert FailedIntent(
                        intentIndex, 0, string.concat("AA24 signature error: invalid signature aggregator")
                    );
                }
                if ((uint256(validatedIntents) & (1 << intentIndex)) == 0) {
                    revert FailedIntent(
                        intentIndex, 0, string.concat("AA24 signature error: intent not part of aggregate")
                    );
                }
            }
        } catch Error(string memory revertReason) {
            revert FailedIntent(intentIndex, 0, string.concat("AA24 signature error: ", revertReason));
        } catch {
            revert FailedIntent(intentIndex, 0, "AA24 signature error (or OOG)");
        }
    }

    /**
     * generates an intent ID for an intent.
     */
    function _generateUserIntentHash(UserIntent calldata intent) private view returns (bytes32) {
        return keccak256(abi.encode(intent.hash(), address(this), block.chainid));
    }
}
