// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {NonceManager} from "./NonceManager.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {CallIntentStandard} from "../standards/CallIntentStandard.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract EntryPoint is IEntryPoint, NonceManager, ReentrancyGuard, CallIntentStandard {
    using IntentSolutionLib for IntentSolution;
    using UserIntentLib for UserIntent;
    using RevertReason for bytes;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;
    uint256 private constant CONTEXT_DATA_MAX_LEN = 2048;

    address private constant EX_STANDARD_NOT_ACTIVE = address(0);
    address private constant EX_STATE_NOT_ACTIVE = address(0);
    address private constant EX_STATE_VALIDATION_EXECUTING =
        address(uint160(uint256(keccak256("EX_STATE_VALIDATION_EXECUTING"))));

    //keeps track of registered intent standards
    mapping(bytes32 => IIntentStandard) private _registeredStandards;

    //flag for applications to check current context of execution
    address private _executionStateContext;
    address private _executionIntentStandard;

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

        // validate timestamp
        uint256 timestamp = solution.getTimestamp();
        require(timestamp > 0, "AA71 invalid timestamp");

        unchecked {
            // validate intents
            for (uint256 i = 0; i < intsLen; i++) {
                bytes32 intentHash = _generateUserIntentHash(solution.intents[i]);
                _validateUserIntentWithAccount(
                    solution.intents[i], intentHash, i, signatureAggregator, validatedIntents
                );

                emit UserIntentEvent(intentHash, solution.intents[i].sender, msg.sender);
            }

            // execute solution
            bytes[] memory contextData = new bytes[](solution.intents.length);
            uint256[] memory intentDataIndexes = new uint256[](solution.intents.length);
            uint256 executionIndex = 0;

            // first loop through the order specified by the solution
            for (; executionIndex < solution.order.length; executionIndex++) {
                uint256 intentIndex = solution.order[executionIndex];
                if (intentDataIndexes[intentIndex] < solution.intents[intentIndex].intentData.length) {
                    contextData[intentIndex] = _executeIntent(
                        solution, executionIndex, intentIndex, intentDataIndexes[intentIndex], contextData[intentIndex]
                    );
                    intentDataIndexes[intentIndex] = intentDataIndexes[intentIndex] + 1;
                }
            }

            // continue looping until all intents have finished executing
            while (true) {
                bool finished = true;
                for (uint256 i = 0; i < solution.intents.length; i++) {
                    if (intentDataIndexes[i] < solution.intents[i].intentData.length) {
                        finished = false;
                        contextData[i] =
                            _executeIntent(solution, executionIndex, i, intentDataIndexes[i], contextData[i]);
                        intentDataIndexes[i] = intentDataIndexes[i] + 1;
                    }
                    executionIndex = executionIndex + 1;
                }
                if (finished) break;
            }

            // no longer executing
            _executionStateContext = EX_STATE_NOT_ACTIVE;
            _executionIntentStandard = EX_STANDARD_NOT_ACTIVE;
        } //unchecked
    }

    /**
     * Execute a user intent.
     * @param solution the full solution context
     * @param executionIndex the current intent execution index
     * @param intentIndex the user intent index in the solution
     * @param segmentIndex the user intent segment index to execute
     * @param contextData the user intent execution context data
     */
    function _executeIntent(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 intentIndex,
        uint256 segmentIndex,
        bytes memory contextData
    ) private returns (bytes memory) {
        UserIntent calldata intent = solution.intents[intentIndex];
        bytes32 standardId = abi.decode(intent.intentData[segmentIndex], (bytes32));
        IIntentStandard intentStandard;
        if (standardId == CALL_INTENT_STANDARD_ID) {
            intentStandard = this;
        } else {
            intentStandard = _registeredStandards[standardId];
            if (intentStandard == IIntentStandard(address(0))) {
                revert FailedIntent(intentIndex, segmentIndex, "AA82 unknown standard");
            }
        }

        _executionStateContext = intent.sender;
        _executionIntentStandard = address(intentStandard);
        bool success = Exec.call(
            address(intentStandard),
            0,
            abi.encodeWithSelector(
                IIntentStandard.executeIntentSegment.selector, solution, executionIndex, segmentIndex, contextData
            ),
            gasleft()
        );
        if (success) {
            if (Exec.getReturnDataSize() > CONTEXT_DATA_MAX_LEN) {
                revert FailedIntent(intentIndex, segmentIndex, "AA60 invalid execution context");
            }
            contextData = Exec.getReturnDataMax(0x40, CONTEXT_DATA_MAX_LEN);
        } else {
            bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
            if (reason.length > 0) {
                revert FailedIntent(
                    intentIndex,
                    segmentIndex,
                    string.concat("AA61 execution failed: ", string(reason.revertReasonWithoutPadding()))
                );
            } else {
                revert FailedIntent(intentIndex, segmentIndex, "AA61 execution failed (or OOG)");
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
        unchecked {
            // loop through solutions and solve
            uint256 solsLen = solutions.length;
            for (uint256 i = 0; i < solsLen; i++) {
                _handleIntents(solutions[i], IAggregator(address(0)), bytes32(0));
            }
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

        unchecked {
            // get number of intents
            uint256 solsLen = solutions.length;
            uint256 totalIntents = 0;
            for (uint256 i = 0; i < solsLen; i++) {
                totalIntents += solutions[0].intents.length;
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
            bytes32 standardId = abi.decode(intent.intentData[i], (bytes32));
            IIntentStandard standard;
            if (standardId == CALL_INTENT_STANDARD_ID) {
                standard = this;
            } else {
                standard = _registeredStandards[standardId];
                if (standard == IIntentStandard(address(0))) {
                    revert FailedIntent(0, i, "AA82 unknown standard");
                }
            }

            // validate the intent segment itself
            try standard.validateIntentSegment(intent.intentData[i]) {}
            catch Error(string memory revertReason) {
                revert FailedIntent(0, i, string.concat("AA62 reverted: ", revertReason));
            } catch {
                revert FailedIntent(0, i, "AA62 reverted (or OOG)");
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
     * registers a new intent standard.
     */
    function registerIntentStandard(IIntentStandard intentStandard) external returns (bytes32) {
        if (address(intentStandard) == address(this)) {
            return CALL_INTENT_STANDARD_ID;
        }
        bytes32 standardId = _generateIntentStandardId(intentStandard);
        require(address(_registeredStandards[standardId]) == address(0), "AA81 already registered");

        _registeredStandards[standardId] = intentStandard;
        return standardId;
    }

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IIntentStandard) {
        if (standardId == CALL_INTENT_STANDARD_ID) {
            return this;
        }
        IIntentStandard intentStandard = _registeredStandards[standardId];
        require(intentStandard != IIntentStandard(address(0)), "AA82 unknown standard");
        return intentStandard;
    }

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(IIntentStandard intentStandard) external view returns (bytes32) {
        if (address(intentStandard) == address(this)) {
            return CALL_INTENT_STANDARD_ID;
        }
        bytes32 standardId = _generateIntentStandardId(intentStandard);
        require(_registeredStandards[standardId] != IIntentStandard(address(0)), "AA82 unknown standard");
        return standardId;
    }

    /**
     * returns true if the given standard is currently executing an intent segment for the msg.sender.
     */
    function verifyExecutingIntentSegmentForStandard(IIntentStandard intentStandard) external view returns (bool) {
        return _executionStateContext == msg.sender && _executionIntentStandard == address(intentStandard);
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
     * generates an intent standard ID for an intent standard contract.
     */
    function _generateIntentStandardId(IIntentStandard intentStandard) private view returns (bytes32) {
        return keccak256(abi.encodePacked(intentStandard, address(this), block.chainid));
    }

    /**
     * generates an intent standard ID for an intent standard contract.
     */
    function _generateUserIntentHash(UserIntent calldata intent) private view returns (bytes32) {
        return keccak256(abi.encode(intent.hash(), address(this), block.chainid));
    }

    /**
     * Manually set the nonce of the sender.
     * @dev this method should only be allowed to be called by the currently executing intent standard contract
     */
    function _setNonce(uint256 key, uint256 nonce) internal override {
        require(msg.sender == _executionIntentStandard, "Invalid nonce access");
        nonceValues[_executionStateContext][key] = nonce;
    }
}
