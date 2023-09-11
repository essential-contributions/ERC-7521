// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {NonceManager} from "./NonceManager.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {DefaultIntentStandard} from "../standards/default/DefaultIntentStandard.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {ValidationData, _parseValidationData} from "../utils/Helpers.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract EntryPoint is IEntryPoint, NonceManager, ReentrancyGuard {
    using IntentSolutionLib for IntentSolution;
    using UserIntentLib for UserIntent;
    using RevertReason for bytes;

    bytes32 private constant DEFAULT_INTENT_STANDARD_ID = 0;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;
    uint256 private constant CONTEXT_DATA_MAX_LEN = 2048;

    address private constant EX_STATE_NOT_ACTIVE = address(0);
    address private constant EX_STATE_VALIDATION_EXECUTING =
        address(uint160(uint256(keccak256("EX_STATE_VALIDATION_EXECUTING"))));

    bytes32 private constant EX_STANDARD_NOT_ACTIVE = bytes32(0);

    //keeps track of registered intent standards
    mapping(bytes32 => IIntentStandard) private _registeredStandards;

    //flag for applications to check current context of execution
    address private _executionStateContext;
    bytes32 private _executionIntentStandardId;

    constructor() {
        _registeredStandards[DEFAULT_INTENT_STANDARD_ID] = new DefaultIntentStandard(this);
    }

    /**
     * Execute a user intents solution.
     * @param solution the user intent solution to execute
     */
    function _executeSolution(IntentSolution calldata solution) private {
        bytes[] memory contextData = new bytes[](solution.intents.length);
        uint256[] memory intentDataIndexes = new uint256[](solution.intents.length);
        uint256 executionIndex = 0;

        unchecked {
            //first loop through the order specified by the solution
            for (; executionIndex < solution.order.length; executionIndex++) {
                uint256 intentIndex = solution.order[executionIndex];
                if (intentDataIndexes[intentIndex] < solution.intents[intentIndex].intentData.length) {
                    _executionStateContext = solution.intents[intentIndex].sender;
                    _executionIntentStandardId = solution.intents[intentIndex].standard;
                    contextData[intentIndex] = _executeIntent(
                        solution, executionIndex, intentIndex, intentDataIndexes[intentIndex], contextData[intentIndex]
                    );
                    intentDataIndexes[intentIndex] = intentDataIndexes[intentIndex] + 1;
                }
            }

            //continue looping until all intents have finished executing
            while (true) {
                bool finished = true;
                for (uint256 i = 0; i < solution.intents.length; i++) {
                    if (intentDataIndexes[i] < solution.intents[i].intentData.length) {
                        finished = false;
                        _executionStateContext = solution.intents[i].sender;
                        _executionIntentStandardId = solution.intents[i].standard;
                        contextData[i] =
                            _executeIntent(solution, executionIndex, i, intentDataIndexes[i], contextData[i]);
                        intentDataIndexes[i] = intentDataIndexes[i] + 1;
                    }
                    executionIndex = executionIndex + 1;
                }
                if (finished) break;
            }

            //Intents no longer executing
            _executionStateContext = EX_STATE_NOT_ACTIVE;
            _executionIntentStandardId = EX_STANDARD_NOT_ACTIVE;
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
        IIntentStandard intentStandard = _registeredStandards[intent.standard];
        bool success = Exec.call(
            address(intentStandard),
            0,
            abi.encodeWithSelector(
                IIntentStandard.executeUserIntent.selector, solution, executionIndex, segmentIndex, contextData
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
    function handleIntents(IntentSolution calldata solution) public nonReentrant {
        // solhint-disable-next-line not-rely-on-time
        uint256 intsLen = solution.intents.length;
        require(intsLen > 0, "AA70 no intents");

        // validate timestamp
        uint256 timestamp = solution.getTimestamp();
        require(timestamp > 0, "AA71 invalid timestamp");

        unchecked {
            bytes32[] memory intentHashes = new bytes32[](intsLen);

            // validate intents
            for (uint256 i = 0; i < intsLen; i++) {
                bytes32 intentHash = getUserIntentHash(solution.intents[i]);
                uint256 validationData = _validateUserIntent(solution.intents[i], intentHash, i);
                _validateAccountValidationData(validationData, i);

                intentHashes[i] = intentHash;
            }

            emit BeforeExecution();

            // execute solution
            _executeSolution(solution);
            for (uint256 i = 0; i < intsLen; i++) {
                emit UserIntentEvent(intentHashes[i], solution.intents[i].sender, msg.sender, solution.intents[i].nonce);
            }
        } //unchecked
    }

    /**
     * Execute a batch of UserIntents using multiple solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleMultiSolutionIntents(IntentSolution[] calldata solutions) public {
        unchecked {
            // loop through solutions and try to solve them individually
            uint256 solsLen = solutions.length;
            for (uint256 i = 0; i < solsLen; i++) {
                try this.handleIntents(solutions[i]) {}
                catch (bytes memory reason) {
                    _emitRevertReason(reason, i);
                }
            }
        }
    }

    /**
     * Simulate full execution of a UserIntent solution (including both validation and target execution).
     * This method will always revert with "ExecutionResult".
     * A timestamp must be set on the solution in order to run.
     * It performs full validation of the UserIntent solution, but ignores signature error.
     * an optional target address is called after the solution succeeds, and its value is returned
     * (before the entire call is reverted)
     * Note that in order to collect the the success/failure of the target call, it must be executed
     * with trace enabled to track the emitted events.
     * @param solution the UserIntent solution to simulate.
     * @param target if nonzero, a target address to call after user intent simulation. If called,
     *        the targetSuccess and targetResult are set to the return from that call.
     * @param targetCallData callData to pass to target address.
     */
    function simulateHandleIntents(IntentSolution calldata solution, address target, bytes calldata targetCallData)
        external
        override
        nonReentrant
    {
        uint256 intsLen = solution.intents.length;
        require(intsLen > 0, "AA70 no intents");

        // validate timestamp
        require(solution.timestamp > 0, "AA72 simulation requires timestamp");

        unchecked {
            // run validation
            for (uint256 i = 0; i < intsLen; i++) {
                _simulationOnlyValidations(solution.intents[i], i);
                bytes32 intentHash = getUserIntentHash(solution.intents[i]);
                uint256 validationData = _validateUserIntent(solution.intents[i], intentHash, i);
                _validateAccountValidationData(validationData, i);
            }

            emit BeforeExecution();

            // execute solution
            numberMarker();
            _executeSolution(solution);
            numberMarker();

            // run target call
            bool targetSuccess;
            bytes memory targetResult;
            if (target != address(0)) {
                (targetSuccess, targetResult) = target.call(targetCallData);
            }

            // return results through a custom error
            revert ExecutionResult(true, targetSuccess, targetResult);
        } //unchecked
    }

    /**
     * Simulate a call to account.validateUserIntent.
     * @dev this method always revert. Successful result is ValidationResult error. other errors are failures.
     * @dev The node must also verify it doesn't use banned opcodes, and that it doesn't reference storage outside the account's data.
     * @param intent the user intent to validate.
     */
    function simulateValidation(UserIntent calldata intent) external {
        _simulationOnlyValidations(intent, 0);
        bytes32 intentHash = getUserIntentHash(intent);
        uint256 validationData = _validateUserIntent(intent, intentHash, 0);
        ValidationData memory valData = _parseValidationData(validationData);

        revert ValidationResult(valData.sigFailed, valData.validAfter, valData.validUntil);
    }

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the intent (except the signature), the entrypoint and the chainid.
     */
    function getUserIntentHash(UserIntent calldata intent) public view returns (bytes32) {
        return keccak256(abi.encode(intent.hash(), address(this), block.chainid));
    }

    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(IIntentStandard intentStandard) external returns (bytes32) {
        require(intentStandard.isIntentStandardForEntryPoint(this), "AA80 invalid standard");

        bytes32 standardId = _generateIntentStandardId(intentStandard);
        require(address(_registeredStandards[standardId]) == address(0), "AA81 already registered");

        _registeredStandards[standardId] = intentStandard;
        return standardId;
    }

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IIntentStandard) {
        IIntentStandard intentStandard = _registeredStandards[standardId];
        require(intentStandard != IIntentStandard(address(0)), "AA82 unknown standard");
        return intentStandard;
    }

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(IIntentStandard intentStandard) external view returns (bytes32) {
        if (address(intentStandard) == address(_registeredStandards[DEFAULT_INTENT_STANDARD_ID])) {
            return DEFAULT_INTENT_STANDARD_ID;
        }
        bytes32 standardId = _generateIntentStandardId(intentStandard);
        require(_registeredStandards[standardId] != IIntentStandard(address(0)), "AA82 unknown standard");
        return standardId;
    }

    /**
     * returns if intent validation actions are currently being executed.
     */
    function validationExecuting() external view returns (bool) {
        return _executionStateContext == EX_STATE_VALIDATION_EXECUTING;
    }

    /**
     * returns the sender of the currently executing intent (or address(0) if no intent is executing).
     */
    function executingIntentSender() external view returns (address) {
        if (_executionStateContext == EX_STATE_VALIDATION_EXECUTING) {
            return EX_STATE_NOT_ACTIVE;
        }

        return _executionStateContext;
    }

    /**
     * returns the standard id of the currently executing intent
     * (or bytes(0) if validation or solution is executing, or if no intent is executing).
     */
    function executingIntentStandardId() external view returns (bytes32) {
        return _executionIntentStandardId;
    }

    /**
     * returns the default intent standard id.
     */
    function getDefaultIntentStandardId() external pure returns (bytes32) {
        return DEFAULT_INTENT_STANDARD_ID;
    }

    /**
     * Called only during simulation.
     */
    function _simulationOnlyValidations(UserIntent calldata intent, uint256 intentIndex) internal view {
        // make sure sender is a deployed contract
        if (intent.sender.code.length == 0) {
            revert FailedIntent(intentIndex, 0, "AA20 account not deployed");
        }
    }

    /**
     * validate user intent.
     * also make sure total validation doesn't exceed verificationGasLimit
     * this method is called off-chain (simulateValidation()) and on-chain (from handleIntents)
     * @param intent the user intent to validate.
     * @param intentHash hash of the user's intent data.
     * @param intentIndex the index of this intent.
     */
    function _validateUserIntent(UserIntent calldata intent, bytes32 intentHash, uint256 intentIndex)
        private
        returns (uint256 validationData)
    {
        _executionStateContext = EX_STATE_VALIDATION_EXECUTING;
        _executionIntentStandardId = EX_STANDARD_NOT_ACTIVE;

        // validate intent standard is recognized
        IIntentStandard standard = _registeredStandards[intent.standard];
        if (address(standard) == address(0)) {
            revert FailedIntent(intentIndex, 0, "AA82 unknown standard");
        }

        // validate the intent itself
        try standard.validateUserIntent(intent) {}
        catch Error(string memory revertReason) {
            revert FailedIntent(intentIndex, 0, string.concat("AA62 reverted: ", revertReason));
        } catch {
            revert FailedIntent(intentIndex, 0, "AA62 reverted (or OOG)");
        }

        // validate intent with account
        try IAccount(intent.sender).validateUserIntent{gas: intent.verificationGasLimit}(intent, intentHash) returns (
            uint256 _validationData
        ) {
            validationData = _validationData;
        } catch Error(string memory revertReason) {
            revert FailedIntent(intentIndex, 0, string.concat("AA23 reverted: ", revertReason));
        } catch {
            revert FailedIntent(intentIndex, 0, "AA23 reverted (or OOG)");
        }

        // validate nonce
        if (!_validateAndUpdateNonce(intent.sender, intent.nonce)) {
            revert FailedIntent(intentIndex, 0, "AA25 invalid account nonce");
        }

        // end validation state
        _executionStateContext = EX_STATE_NOT_ACTIVE;
    }

    /**
     * revert if account validationData is expired
     */
    function _validateAccountValidationData(uint256 validationData, uint256 intentIndex) internal view {
        if (validationData != 0) {
            ValidationData memory data = _parseValidationData(validationData);
            if (data.sigFailed) {
                revert FailedIntent(intentIndex, 0, "AA24 signature error");
            }
            // solhint-disable-next-line not-rely-on-time
            bool outOfTimeRange = block.timestamp > data.validUntil || block.timestamp < data.validAfter;
            if (outOfTimeRange) {
                revert FailedIntent(intentIndex, 0, "AA22 expired or not due");
            }
        }
    }

    /**
     * emits an event based on the revert reason
     */
    function _emitRevertReason(bytes memory reason, uint256 solIndex) private {
        // get error selector
        bytes4 selector = 0x00000000;
        if (reason.length >= 4) {
            assembly {
                selector := mload(add(0x20, reason))
            }
        }

        // convert error to event to emit
        if (selector == FailedIntent.selector) {
            // revert was due to a FailedIntent error
            uint256 intIndex;
            uint256 segIndex;
            assembly {
                intIndex := mload(add(0x24, reason))
                segIndex := mload(add(0x44, reason))
                reason := add(reason, 0x84)
            }
            emit UserIntentRevertReason(solIndex, intIndex, segIndex, string(reason));
        } else if (_checkErrorCode(selector)) {
            //revert was due to a certain error code
            emit UserIntentRevertReason(solIndex, 0, 0, string(reason));
        } else if (reason.length > 0) {
            //revert was due to some unknown with a reason string
            emit UserIntentRevertReason(solIndex, 0, 0, string.concat("AA62 reverted: ", string(reason)));
        } else {
            //revert was due to some unknown
            emit UserIntentRevertReason(solIndex, 0, 0, "AA62 reverted (or OOG)");
        }
    }

    /**
     * checks if the given bytes are an error code (follows pattern AAxx where x is a digit from 0-9)
     */
    function _checkErrorCode(bytes4 selector) private pure returns (bool) {
        return (selector & 0xFFFF0000) == 0x41410000 && (selector & 0x0000FF00) >= 0x00003000
            && (selector & 0x0000FF00) <= 0x00003900 && (selector & 0x000000FF) >= 0x00000030
            && (selector & 0x000000FF) <= 0x00000039;
    }

    /**
     * generates an intent standard ID for an intent standard contract.
     */
    function _generateIntentStandardId(IIntentStandard intentStandard) private view returns (bytes32) {
        return keccak256(abi.encodePacked(intentStandard, address(this), block.chainid));
    }

    //place the NUMBER opcode in the code.
    // this is used as a marker during simulation, as this OP is completely banned from the simulated code of the
    // account.
    function numberMarker() internal view {
        assembly {
            mstore(0, number())
        }
    }
}
