// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {IntentStandardRegistry} from "./IntentStandardRegistry.sol";
import {INonceManager, NonceManager} from "./NonceManager.sol";
import {EmbeddedIntentStandards, NUM_EMBEDDED_STANDARDS} from "./EmbeddedIntentStandards.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";
import {IERC165, ERC165} from "openzeppelin/utils/introspection/ERC165.sol";

contract EntryPoint is
    IEntryPoint,
    NonceManager,
    IntentStandardRegistry,
    EmbeddedIntentStandards,
    ReentrancyGuard,
    ERC165
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
     */
    function _handleIntents(IntentSolution calldata solution) private nonReentrant {
        uint256 intsLen = solution.intents.length;
        require(intsLen > 0, "AA70 no intents");
        require(intsLen <= 32, "AA72 too many intents");
        require(solution.getTimestamp() > 0, "AA71 invalid timestamp");

        unchecked {
            // validate intents
            for (uint256 i = 0; i < intsLen; i++) {
                UserIntent calldata intent = solution.intents[i];
                bytes32 intentHash = intent.hash();
                uint256 numSegments = intent.segments.length;
                if (numSegments > 256) {
                    revert FailedIntent(i, 0, string.concat("AA63 too many segments"));
                }
                if (intent.sender != address(0) && numSegments > 0) {
                    _validateUserIntentWithAccount(intent, intentHash, i);
                    emit UserIntentEvent(_generateUserIntentHash(intentHash), intent.sender, msg.sender);
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
                uint256 numSegments = solution.intents[intentIndex].segments.length;

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
        if (intent.sender != address(0) && intent.segments.length > 0) {
            bytes32 standardId = intent.getSegmentStandard(segmentIndex);

            // check if this is an embedded standard
            if (uint256(standardId) < NUM_EMBEDDED_STANDARDS) {
                _executionState = keccak256(abi.encodePacked(intent.sender, address(this)));
                contextData = _handleEmbeddedIntentSegment(
                    standardId, solution, intent, segmentIndex, executionIndex, contextData
                );
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
        _handleIntents(solution);
    }

    /**
     * Execute a batch of UserIntents using multiple solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleIntentsMulti(IntentSolution[] calldata solutions) external {
        // loop through solutions and solve
        uint256 solsLen = solutions.length;
        for (uint256 i = 0; i < solsLen; i++) {
            _handleIntents(solutions[i]);
        }
    }

    /**
     * Run validation for the given intent.
     * @param intent the user intent to validate.
     */
    function validateIntent(UserIntent calldata intent) external {
        // make sure sender is a deployed contract
        if (intent.sender.code.length == 0) {
            revert FailedIntent(0, 0, "AA20 account not deployed");
        }

        // validate intent standards are recognized and formatted correctly
        for (uint256 i = 0; i < intent.segments.length; i++) {
            bytes32 standardId = intent.getSegmentStandard(i);
            // validate the intent segment itself
            if (uint256(standardId) < NUM_EMBEDDED_STANDARDS) {
                _validateEmbeddedIntentSegment(standardId, intent.segments[i]);
            } else {
                IIntentStandard standard = _registeredStandards[standardId];
                if (standard == IIntentStandard(address(0))) {
                    revert FailedIntent(0, i, "AA82 unknown standard");
                }

                // validate the intent segment itself
                try standard.validateIntentSegment(intent.segments[i]) {}
                catch Error(string memory revertReason) {
                    revert FailedIntent(0, i, string.concat("AA62 reverted: ", revertReason));
                } catch {
                    revert FailedIntent(0, i, "AA62 reverted (or OOG)");
                }
            }
        }

        // validate signature
        _validateUserIntentWithAccount(intent, intent.hash(), 0);
    }

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the intent (except the signature), the entrypoint and the chainid.
     */
    function getUserIntentHash(UserIntent calldata intent) external view returns (bytes32) {
        return _generateUserIntentHash(intent.hash());
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == (type(IEntryPoint).interfaceId ^ type(INonceManager).interfaceId)
            || interfaceId == type(IEntryPoint).interfaceId || interfaceId == type(INonceManager).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * Validate user intent.
     * @param intent the user intent to validate.
     * @param intentHash hash of the user's intent data.
     * @param intentIndex the index of this intent.
     */
    function _validateUserIntentWithAccount(UserIntent calldata intent, bytes32 intentHash, uint256 intentIndex)
        private
    {
        try IAccount(intent.sender).validateUserIntent(intent, intentHash) {}
        catch Error(string memory revertReason) {
            revert FailedIntent(intentIndex, 0, string.concat("AA24 signature error: ", revertReason));
        } catch {
            revert FailedIntent(intentIndex, 0, "AA24 signature error (or OOG)");
        }
    }

    /**
     * generates an intent ID for an intent.
     */
    function _generateUserIntentHash(bytes32 intentHash) private view returns (bytes32) {
        return keccak256(abi.encode(intentHash, address(this), block.chainid));
    }
}
