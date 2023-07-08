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
import {ValidationData, _parseValidationData, _intersectTimeRange} from "./Helpers.sol";
import {ReentrancyGuard} from "openzeppelin/security/ReentrancyGuard.sol";

contract EntryPoint is IEntryPoint, NonceManager, ReentrancyGuard {
    using UserIntentLib for UserIntent;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;
    uint256 private constant CONTEXT_DATA_MAX_LEN = 2048;

    //keeps track of registered intent standards
    mapping(bytes32 => IIntentStandard) private _registeredStandards;

    //flag for applications to check current step in execution
    ExState private _executionState;

    /**
     * execution state flags
     */
    enum ExState {
        notActive,
        validationExecuting,
        intentExecuting,
        solutionExecuting
    }

    /**
     * execute a user intent solution
     * @param solIndex index into the solution array
     * @param solution the user intent solution to execute
     * @param intInfo the intent info filled by validateUserIntent
     * @param timestamp the time at which to evaluate the intents
     */
    function _executeSolution(
        uint256 solIndex,
        IntentSolution calldata solution,
        UserIntInfo[] memory intInfo,
        uint256 timestamp
    ) private {
        uint256 intslen = solution.userInts.length;
        bytes[] memory contextData = new bytes[](intslen);

        //TODO: is this gas check necessary? (copied from 4337)
        /*
        if (gasleft() < mUserOp.callGasLimit + mUserOp.verificationGasLimit + 5000) {
            revert FailedOp(solIndex, "AA95 out of gas");
        }
        */

        unchecked {
            //Execute callData1
            _executionState = ExState.intentExecuting;
            for (uint256 i = 0; i < intslen; i++) {
                IIntentStandard standard = _registeredStandards[solution.userInts[i].getStandard()];
                bool success = Exec.delegateCall(
                    address(standard),
                    abi.encodeWithSelector(IIntentStandard.executeFirstPass.selector, solution.userInts[i], timestamp),
                    gasleft()
                );
                if (success) {
                    if (Exec.getReturnDataSize() > CONTEXT_DATA_MAX_LEN) {
                        _executionState = ExState.notActive;
                        revert FailedInt(solIndex, i, "AA95 context too large"); //TODO: double check error code format
                    }
                    contextData[i] = Exec.getReturnData();
                } else {
                    bytes memory result = Exec.getReturnDataMax(REVERT_REASON_MAX_LEN);
                    if (result.length > 0) {
                        emit UserIntentRevertReason(intInfo[i].userIntHash, intInfo[i].sender, intInfo[i].nonce, result);
                    }
                    _executionState = ExState.notActive;
                    revert FailedInt(solIndex, i, "AA95 callData1 revert"); //TODO: double check error code format
                }
            }

            //Execute solution1
            uint256 solLen1 = solution.steps1.length;
            if (solLen1 > 0) {
                _executionState = ExState.solutionExecuting;
                for (uint256 i = 0; i < solLen1; i++) {
                    SolutionStep calldata step = solution.steps1[i];
                    bool success = Exec.call(step.target, step.value, step.callData, gasleft());
                    if (!success) {
                        bytes memory result = Exec.getReturnDataMax(REVERT_REASON_MAX_LEN);
                        if (result.length > 0) {
                            _executionState = ExState.notActive;
                            emit SolutionRevertReason(i, step.target, result);
                            revert FailedInt(solIndex, 0, "AA95 solution steps1 revert"); //TODO: double check error code format
                        }
                    }
                }
            }

            //Execute callData2
            _executionState = ExState.intentExecuting;
            for (uint256 i = 0; i < intslen; i++) {
                IIntentStandard standard = _registeredStandards[solution.userInts[i].getStandard()];
                bool success = Exec.delegateCall(
                    address(standard),
                    abi.encodeWithSelector(IIntentStandard.executeSecondPass.selector, solution.userInts[i], timestamp),
                    gasleft()
                );
                if (!success) {
                    bytes memory result = Exec.getReturnDataMax(REVERT_REASON_MAX_LEN);
                    if (result.length > 0) {
                        emit UserIntentRevertReason(intInfo[i].userIntHash, intInfo[i].sender, intInfo[i].nonce, result);
                    }
                    _executionState = ExState.notActive;
                    revert FailedInt(solIndex, i, "AA95 callData2 revert"); //TODO: double check error code format
                }
            }

            //Execute solution2
            uint256 solLen2 = solution.steps2.length;
            if (solLen2 > 0) {
                _executionState = ExState.solutionExecuting;
                for (uint256 i = 0; i < solLen2; i++) {
                    SolutionStep calldata step = solution.steps2[i];
                    bool success = Exec.call(step.target, step.value, step.callData, gasleft());
                    if (!success) {
                        bytes memory result = Exec.getReturnDataMax(REVERT_REASON_MAX_LEN);
                        if (result.length > 0) {
                            emit SolutionRevertReason(i, step.target, result);
                        }
                        _executionState = ExState.notActive;
                        revert FailedInt(solIndex, 0, "AA95 solution steps2 revert"); //TODO: double check error code format
                    }
                }
            }

            //Verify end state
            _executionState = ExState.intentExecuting;
            for (uint256 i = 0; i < intslen; i++) {
                IIntentStandard standard = _registeredStandards[solution.userInts[i].getStandard()];
                bool success = Exec.delegateCall(
                    address(standard),
                    abi.encodeWithSelector(
                        IIntentStandard.verifyEndState.selector, solution.userInts[i], timestamp, contextData[i]
                    ),
                    gasleft()
                );
                if (!success) {
                    bytes memory result = Exec.getReturnDataMax(REVERT_REASON_MAX_LEN);
                    if (result.length > 0) {
                        emit UserIntentRevertReason(intInfo[i].userIntHash, intInfo[i].sender, intInfo[i].nonce, result);
                    }
                    _executionState = ExState.notActive;
                    revert FailedInt(solIndex, i, "AA95 end state verify revert"); //TODO: double check error code format
                }
            }

            //Solution was successful for all intents
            for (uint256 i = 0; i < intslen; i++) {
                emit UserIntentEvent(intInfo[i].userIntHash, intInfo[i].sender, msg.sender, intInfo[i].nonce);
            }

            //Intent no longer executing
            _executionState = ExState.notActive;
        } //unchecked
    }

    /**
     * Execute a batch of UserIntents with given solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleInts(IntentSolution[] calldata solutions) public nonReentrant {
        uint256 solsLen = solutions.length;
        UserIntInfo[][] memory intInfo = new UserIntInfo[][](solsLen);

        unchecked {
            for (uint256 i = 0; i < solsLen; i++) {
                uint256 intsLen = solutions[i].userInts.length;
                if (intsLen == 0) {
                    revert FailedInt(i, 0, "AA95 solution has no intents"); //TODO: double check error code format
                }
                intInfo[i] = new UserIntInfo[](intsLen);
                for (uint256 j = 0; j < intsLen; j++) {
                    uint256 validationData = _validateUserIntent(i, j, solutions[i].userInts[j], intInfo[i][j]);
                    _validateAccountValidationData(i, j, validationData);
                }
            }

            emit BeforeExecution();

            // solhint-disable-next-line not-rely-on-time
            uint256 timestamp = block.timestamp;
            for (uint256 i = 0; i < solsLen; i++) {
                _executeSolution(i, solutions[i], intInfo[i], timestamp);
            }
        } //unchecked
    }

    /**
     * simulate full execution of a UserIntent solution (including both validation and target execution)
     * this method will always revert with "ExecutionResult".
     * it performs full validation of the UserIntent solution, but ignores signature error.
     * an optional target address is called after the solution succeeds, and its value is returned
     * (before the entire call is reverted)
     * Note that in order to collect the the success/failure of the target call, it must be executed
     * with trace enabled to track the emitted events.
     * @param solution the UserIntent solution to simulate
     * @param timestamp the timestamp at which to evaluate the intents
     * @param target if nonzero, a target address to call after user intent simulation. If called,
     *        the targetSuccess and targetResult are set to the return from that call.
     * @param targetCallData callData to pass to target address
     */
    function simulateHandleInt(
        IntentSolution calldata solution,
        uint256 timestamp,
        address target,
        bytes calldata targetCallData
    ) external override {
        uint256 intsLen = solution.userInts.length;
        UserIntInfo[] memory intInfo = new UserIntInfo[](intsLen);
        if (intsLen == 0) {
            revert FailedInt(0, 0, "AA95 solution has no intents"); //TODO: double check error code format
        }

        // run validation for first intent
        _simulationOnlyValidations(solution.userInts[0]);
        uint256 validationData = _validateUserIntent(0, 0, solution.userInts[0], intInfo[0]);
        ValidationData memory combinedValData = _parseValidationData(validationData);

        // run validation for the other intents
        for (uint256 i = 1; i < intsLen; i++) {
            _simulationOnlyValidations(solution.userInts[i]);
            validationData = _validateUserIntent(0, i, solution.userInts[i], intInfo[i]);
            ValidationData memory newValData = _parseValidationData(validationData);
            combinedValData = _intersectTimeRange(combinedValData, newValData);
        }

        numberMarker();
        _executeSolution(0, solution, intInfo, timestamp);
        numberMarker();

        bool targetSuccess;
        bytes memory targetResult;
        if (target != address(0)) {
            (targetSuccess, targetResult) = target.call(targetCallData);
        }
        revert ExecutionResult(combinedValData.validAfter, combinedValData.validUntil, targetSuccess, targetResult);
    }

    /**
     * Simulate a call to account.validateUserInt.
     * @dev this method always revert. Successful result is ValidationResult error. other errors are failures.
     * @dev The node must also verify it doesn't use banned opcodes, and that it doesn't reference storage outside the account's data.
     * @param userInt the user intent to validate.
     */
    function simulateValidation(UserIntent calldata userInt) external {
        UserIntInfo memory intInfo;

        _simulationOnlyValidations(userInt);
        uint256 validationData = _validateUserIntent(0, 0, userInt, intInfo);
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
        require(address(_registeredStandards[standardId]) == address(0), "AA95 already registered"); //TODO: double check error code format

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
        return _executionState == ExState.validationExecuting;
    }

    /**
     * returns if intent specific actions are currently being executed.
     */
    function intentExecuting() external view returns (bool) {
        return _executionState == ExState.intentExecuting;
    }

    /**
     * returns if intent solution specific actions are currently being executed.
     */
    function solutionExecuting() external view returns (bool) {
        return _executionState == ExState.solutionExecuting;
    }

    /**
     * Called only during simulation.
     */
    function _simulationOnlyValidations(UserIntent calldata userInt) internal view {
        // make sure sender is a deployed contract
        if (userInt.sender.code.length == 0) {
            revert FailedInt(0, 0, "AA20 account not deployed");
        }
    }

    /**
     * revert if account validationData is expired
     */
    function _validateAccountValidationData(uint256 solIndex, uint256 intIndex, uint256 validationData) internal view {
        if (validationData == 0) {
            ValidationData memory data = _parseValidationData(validationData);
            if (data.sigFailed) {
                revert FailedInt(solIndex, intIndex, "AA24 signature error");
            }
            // solhint-disable-next-line not-rely-on-time
            bool outOfTimeRange = block.timestamp > data.validUntil || block.timestamp < data.validAfter;
            if (outOfTimeRange) {
                revert FailedInt(solIndex, intIndex, "AA22 expired or not due");
            }
        }
    }

    // A memory copy of UserInt static fields only.
    // Also includes the hash of the UserInt.
    struct UserIntInfo {
        bytes32 standard;
        address sender;
        uint256 nonce;
        uint256 verificationGasLimit;
        bytes32 userIntHash;
    }

    /**
     * validate account and paymaster (if defined).
     * also make sure total validation doesn't exceed verificationGasLimit
     * this method is called off-chain (simulateValidation()) and on-chain (from handleInts)
     * @param solIndex the index of this solution into the solution array
     * @param intIndex the index of this intent into the solution intent array
     * @param userInt the user intent to validate
     * @param intInfo the user intent info to populate
     */
    //TODO: does returning a parsed ValidationData save gas? (including intersecting with already parsed data)
    function _validateUserIntent(
        uint256 solIndex,
        uint256 intIndex,
        UserIntent calldata userInt,
        UserIntInfo memory intInfo
    ) private returns (uint256 validationData) {
        _executionState = ExState.validationExecuting;

        // validate intent standard is recognized
        IIntentStandard standard = _registeredStandards[userInt.getStandard()];
        if (address(standard) == address(0)) {
            _executionState = ExState.notActive;
            revert FailedInt(solIndex, intIndex, "AA95 unknown intent standard"); //TODO: double check error code format
        }

        // validate the intent itself
        try standard.validateUserInt(userInt) returns (uint256 _validationData) {
            validationData = _validationData;
        } catch Error(string memory revertReason) {
            _executionState = ExState.notActive;
            revert FailedInt(solIndex, intIndex, string.concat("AA23 reverted: ", revertReason)); //TODO: double check error code format
        } catch {
            _executionState = ExState.notActive;
            revert FailedInt(solIndex, intIndex, "AA23 reverted (or OOG)"); //TODO: double check error code format
        }

        // copy info about the intent to memory for easy reference later
        intInfo.standard = userInt.getStandard();
        intInfo.sender = userInt.sender;
        intInfo.nonce = userInt.nonce;
        intInfo.verificationGasLimit = userInt.verificationGasLimit;
        intInfo.userIntHash = getUserIntHash(userInt);

        // validate intent with account
        try IAccount(intInfo.sender).validateUserInt{gas: intInfo.verificationGasLimit}(userInt, intInfo.userIntHash)
        returns (uint256 _validationData) {
            validationData = _intersectTimeRange(validationData, _validationData);
        } catch Error(string memory revertReason) {
            _executionState = ExState.notActive;
            revert FailedInt(solIndex, intIndex, string.concat("AA23 reverted: ", revertReason));
        } catch {
            _executionState = ExState.notActive;
            revert FailedInt(solIndex, intIndex, "AA23 reverted (or OOG)");
        }

        // validate nonce
        if (!_validateAndUpdateNonce(intInfo.sender, intInfo.nonce)) {
            _executionState = ExState.notActive;
            revert FailedInt(solIndex, intIndex, "AA25 invalid account nonce");
        }

        // end validation state
        _executionState = ExState.notActive;
    }

    //place the NUMBER opcode in the code.
    // this is used as a marker during simulation, as this OP is completely banned from the simulated code of the
    // account and paymaster.
    function numberMarker() internal view {
        assembly {
            mstore(0, number())
        }
    }
}
