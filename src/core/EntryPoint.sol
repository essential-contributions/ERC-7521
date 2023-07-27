// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {NonceManager} from "./NonceManager.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";
import {ValidationData, _parseValidationData} from "../utils/Helpers.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract EntryPoint is IEntryPoint, NonceManager, ReentrancyGuard {
    using UserIntentLib for UserIntent;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;
    uint256 private constant CONTEXT_DATA_MAX_LEN = 2048;

    address private constant EX_STATE_NOT_ACTIVE = address(0);
    address private constant EX_STATE_VALIDATION_EXECUTING =
        address(uint160(uint256(keccak256("EX_STATE_VALIDATION_EXECUTING"))));
    address private constant EX_STATE_SOLUTION_EXECUTING =
        address(uint160(uint256(keccak256("EX_STATE_SOLUTION_EXECUTING"))));

    //keeps track of registered intent standards
    mapping(bytes32 => IIntentStandard) private _registeredStandards;

    //flag for applications to check current context of execution
    address private _executionStateContext;

    /**
     * execute a user intents solution.
     * @param solution the user intent solution to execute
     * @param timestamp the time at which to evaluate the intents
     */
    function _executeSolution(IntentSolution calldata solution, uint256 timestamp) private {
        uint256 intslen = solution.userIntents.length;
        bytes[] memory contextData = new bytes[](intslen);
        bool[] memory executionFinished = new bool[](intslen);
        bool solutionFinished = solution.solutionSegments.length == 0;
        bool intentsFinished = false;
        uint256 passIndex = 0;

        unchecked {
            while (!intentsFinished || !solutionFinished) {
                //Execute intents
                if (!intentsFinished) {
                    bool stillExecuting = false;
                    for (uint256 i = 0; i < intslen; i++) {
                        if (!executionFinished[i]) {
                            UserIntent calldata intent = solution.userIntents[i];
                            _executionStateContext = intent.sender;
                            IIntentStandard standard = _registeredStandards[intent.getStandard()];
                            bool success = Exec.delegateCall(
                                address(standard),
                                abi.encodeWithSelector(
                                    IIntentStandard.executeUserIntent.selector, intent, timestamp, contextData[i]
                                ),
                                gasleft()
                            );
                            if (success) {
                                if (Exec.getReturnDataSize() > CONTEXT_DATA_MAX_LEN) {
                                    revert FailedIntent(i, passIndex, "AA60 invalid execution context");
                                }
                                contextData[i] = Exec.getReturnDataMax(0x40, CONTEXT_DATA_MAX_LEN);
                                if (contextData[i].length > 0) {
                                    stillExecuting = true;
                                } else {
                                    executionFinished[i] = true;
                                }
                            } else {
                                bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
                                if (reason.length > 0) {
                                    revert FailedIntent(
                                        i, passIndex, string.concat("AA61 execution failed: ", string(reason))
                                    );
                                } else {
                                    revert FailedIntent(i, passIndex, "AA61 execution failed (or OOG)");
                                }
                            }
                        }
                    }
                    intentsFinished = !stillExecuting;
                }

                //Execute solution
                if (!solutionFinished) {
                    uint256 solLen = solution.solutionSegments[passIndex].steps.length;
                    if (solLen > 0) {
                        _executionStateContext = EX_STATE_SOLUTION_EXECUTING;
                        for (uint256 i = 0; i < solLen; i++) {
                            SolutionStep calldata step = solution.solutionSegments[passIndex].steps[i];
                            bool success = Exec.call(step.target, step.value, step.callData, gasleft());
                            if (!success) {
                                bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
                                if (reason.length > 0) {
                                    revert FailedSolution(i, string.concat("AA71 execution failed: ", string(reason)));
                                } else {
                                    revert FailedSolution(i, "AA71 execution failed (or OOG)");
                                }
                            }
                        }
                    }
                    solutionFinished = (passIndex + 1) >= solution.solutionSegments.length;
                }

                passIndex++;
            }

            //Intent no longer executing
            _executionStateContext = EX_STATE_NOT_ACTIVE;
        } //unchecked
    }

    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     */
    function handleIntents(IntentSolution calldata solution) public nonReentrant {
        // solhint-disable-next-line not-rely-on-time
        uint256 timestamp = block.timestamp;
        uint256 intsLen = solution.userIntents.length;
        require(intsLen > 0, "AA70 no intents");

        unchecked {
            bytes32[] memory userIntHashes = new bytes32[](intsLen);

            // validate intents
            for (uint256 i = 0; i < intsLen; i++) {
                bytes32 userIntHash = getUserIntHash(solution.userIntents[i]);
                uint256 validationData = _validateUserIntent(solution.userIntents[i], userIntHash, i);
                _validateAccountValidationData(validationData, i);

                userIntHashes[i] = userIntHash;
            }

            emit BeforeExecution();

            // execute solution
            _executeSolution(solution, timestamp);
            for (uint256 i = 0; i < intsLen; i++) {
                emit UserIntentEvent(
                    userIntHashes[i], solution.userIntents[i].sender, msg.sender, solution.userIntents[i].nonce
                );
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
     * simulate full execution of a UserIntent solution (including both validation and target execution)
     * this method will always revert with "ExecutionResult".
     * it performs full validation of the UserIntent solution, but ignores signature error.
     * an optional target address is called after the solution succeeds, and its value is returned
     * (before the entire call is reverted)
     * Note that in order to collect the the success/failure of the target call, it must be executed
     * with trace enabled to track the emitted events.
     * @param solution the UserIntents solution to simulate.
     * @param timestamp the timestamp at which to evaluate the intents.
     * @param target if nonzero, a target address to call after user intent simulation. If called,
     *        the targetSuccess and targetResult are set to the return from that call.
     * @param targetCallData callData to pass to target address.
     */
    function simulateHandleIntents(
        IntentSolution calldata solution,
        uint256 timestamp,
        address target,
        bytes calldata targetCallData
    ) external override nonReentrant {
        uint256 intsLen = solution.userIntents.length;
        require(intsLen > 0, "AA70 no intents");

        unchecked {
            // run validation
            for (uint256 i = 0; i < intsLen; i++) {
                _simulationOnlyValidations(solution.userIntents[i], i);
                bytes32 userIntHash = getUserIntHash(solution.userIntents[i]);
                uint256 validationData = _validateUserIntent(solution.userIntents[i], userIntHash, i);
                _validateAccountValidationData(validationData, i);
            }

            emit BeforeExecution();

            // execute solution
            numberMarker();
            _executeSolution(solution, timestamp);
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
     * Simulate a call to account.validateUserInt.
     * @dev this method always revert. Successful result is ValidationResult error. other errors are failures.
     * @dev The node must also verify it doesn't use banned opcodes, and that it doesn't reference storage outside the account's data.
     * @param userInt the user intent to validate.
     */
    function simulateValidation(UserIntent calldata userInt) external {
        _simulationOnlyValidations(userInt, 0);
        bytes32 userIntHash = getUserIntHash(userInt);
        uint256 validationData = _validateUserIntent(userInt, userIntHash, 0);
        ValidationData memory valData = _parseValidationData(validationData);

        revert ValidationResult(valData.sigFailed, valData.validAfter, valData.validUntil);
    }

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the userInt (except the signature), the entrypoint and the chainid.
     */
    function getUserIntHash(UserIntent calldata userInt) public view returns (bytes32) {
        return keccak256(abi.encode(userInt.hash(), address(this), block.chainid));
    }

    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(IIntentStandard standardContract) external returns (bytes32) {
        //TODO: revisit how IDs are generated
        bytes32 standardId = keccak256(abi.encodePacked(standardContract, address(this)));
        require(address(_registeredStandards[standardId]) == address(0), "AA80 already registered");

        _registeredStandards[standardId] = standardContract;
        return standardId;
    }

    /**
     * gets the intent contract for the given standard (address(0) if unknown).
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IIntentStandard) {
        return _registeredStandards[standardId];
    }

    /**
     * returns if intent validation actions are currently being executed.
     */
    function validationExecuting() external view returns (bool) {
        return _executionStateContext == EX_STATE_VALIDATION_EXECUTING;
    }

    /**
     * returns the sender of the currently executing intent (or address(0) is no intent is executing).
     */
    function executingIntentSender() external view returns (address) {
        if (
            _executionStateContext == EX_STATE_VALIDATION_EXECUTING
                || _executionStateContext == EX_STATE_SOLUTION_EXECUTING
        ) {
            return EX_STATE_NOT_ACTIVE;
        }

        return _executionStateContext;
    }

    /**
     * returns if intent solution specific actions are currently being executed.
     */
    function solutionExecuting() external view returns (bool) {
        return _executionStateContext == EX_STATE_SOLUTION_EXECUTING;
    }

    /**
     * Called only during simulation.
     */
    function _simulationOnlyValidations(UserIntent calldata userInt, uint256 userIntIndex) internal view {
        // make sure sender is a deployed contract
        if (userInt.sender.code.length == 0) {
            revert FailedIntent(userIntIndex, 0, "AA20 account not deployed");
        }
    }

    /**
     * validate user intent.
     * also make sure total validation doesn't exceed verificationGasLimit
     * this method is called off-chain (simulateValidation()) and on-chain (from handleIntents)
     * @param userInt the user intent to validate.
     * @param userIntHash hash of the user's intent data.
     * @param userIntIndex the index of this intent.
     */
    function _validateUserIntent(UserIntent calldata userInt, bytes32 userIntHash, uint256 userIntIndex)
        private
        returns (uint256 validationData)
    {
        _executionStateContext = EX_STATE_VALIDATION_EXECUTING;

        // validate intent standard is recognized
        IIntentStandard standard = _registeredStandards[userInt.getStandard()];
        if (address(standard) == address(0)) {
            revert FailedIntent(userIntIndex, 0, "AA81 unknown standard");
        }

        // validate the intent itself
        try standard.validateUserInt(userInt) {}
        catch Error(string memory revertReason) {
            revert FailedIntent(userIntIndex, 0, string.concat("AA62 reverted: ", revertReason));
        } catch {
            revert FailedIntent(userIntIndex, 0, "AA62 reverted (or OOG)");
        }

        // validate intent with account
        try IAccount(userInt.sender).validateUserInt{gas: userInt.verificationGasLimit}(userInt, userIntHash) returns (
            uint256 _validationData
        ) {
            validationData = _validationData;
        } catch Error(string memory revertReason) {
            revert FailedIntent(userIntIndex, 0, string.concat("AA23 reverted: ", revertReason));
        } catch {
            revert FailedIntent(userIntIndex, 0, "AA23 reverted (or OOG)");
        }

        // validate nonce
        if (!_validateAndUpdateNonce(userInt.sender, userInt.nonce)) {
            revert FailedIntent(userIntIndex, 0, "AA25 invalid account nonce");
        }

        // end validation state
        _executionStateContext = EX_STATE_NOT_ACTIVE;
    }

    /**
     * revert if account validationData is expired
     */
    function _validateAccountValidationData(uint256 validationData, uint256 userIntIndex) internal view {
        if (validationData == 0) {
            ValidationData memory data = _parseValidationData(validationData);
            if (data.sigFailed) {
                revert FailedIntent(userIntIndex, 0, "AA24 signature error");
            }
            // solhint-disable-next-line not-rely-on-time
            bool outOfTimeRange = block.timestamp > data.validUntil || block.timestamp < data.validAfter;
            if (outOfTimeRange) {
                revert FailedIntent(userIntIndex, 0, "AA22 expired or not due");
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
        } else if (selector == FailedSolution.selector) {
            // revert was due to a FailedSolution error
            uint256 stepIndex;
            assembly {
                stepIndex := mload(add(0x24, reason))
                reason := add(reason, 0x64)
            }
            emit SolutionRevertReason(solIndex, stepIndex, string(reason));
        } else if (_checkErrorCode(selector)) {
            //revert was due to a certain error code
            emit SolutionRevertReason(solIndex, 0, string(reason));
        } else if (reason.length > 0) {
            //revert was due to some unknown with a reason string
            emit SolutionRevertReason(solIndex, 0, string.concat("AA72 reverted: ", string(reason)));
        } else {
            //revert was due to some unknown
            emit SolutionRevertReason(solIndex, 0, "AA72 reverted (or OOG)");
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

    //place the NUMBER opcode in the code.
    // this is used as a marker during simulation, as this OP is completely banned from the simulated code of the
    // account.
    function numberMarker() internal view {
        assembly {
            mstore(0, number())
        }
    }
}
