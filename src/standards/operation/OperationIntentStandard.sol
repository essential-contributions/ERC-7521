// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {EntryPointTruster} from "../../core/EntryPointTruster.sol";
import {IIntentStandard} from "../../interfaces/IIntentStandard.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../../interfaces/IntentSolution.sol";
import {Exec} from "../../utils/Exec.sol";
import {OperationIntentSegment, parseOperationIntentSegment} from "./OperationIntentSegment.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract OperationIntentStandard is IIntentStandard, EntryPointTruster {
    using IntentSolutionLib for IntentSolution;
    using UserIntentLib for UserIntent;

    /**
     * Basic state and constants.
     */
    IEntryPoint private immutable _entryPoint;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Contract constructor.
     * @param entryPointContract the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPointContract) {
        _entryPoint = entryPointContract;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function standardId() public view returns (bytes32) {
        return _entryPoint.getIntentStandardId(this);
    }

    /**
     * Operation receive function.
     */
    receive() external payable {}

    /**
     * Validate intent structure (typically just formatting)
     * @param intent the intent that is about to be solved.
     */
    function validateUserIntent(UserIntent calldata intent) external pure {}

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @return context to remember for further execution.
     */
    function executeUserIntent(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory
    ) external onlyFromEntryPoint returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        if (intent.intentData[segmentIndex].length > 0) {
            OperationIntentSegment calldata dataSegment = parseOperationIntentSegment(intent, segmentIndex);

            //execute calldata
            if (dataSegment.callData.length > 0) {
                Exec.callAndRevert(intent.sender, dataSegment.callData, dataSegment.callGasLimit, REVERT_REASON_MAX_LEN);
            }
        }
        return "";
    }

    /**
     * Verifies the intent standard is for a given entry point contract (required for registration on the entry point).
     * @param entryPointContract the entry point contract.
     * @return flag indicating if the intent standard is for the given entry point.
     */
    function isIntentStandardForEntryPoint(IEntryPoint entryPointContract) external view returns (bool) {
        return entryPointContract == _entryPoint;
    }
}
