// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import "forge-std/Test.sol";
import {EntryPointTruster} from "../core/EntryPointTruster.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {Exec} from "../utils/Exec.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * User Operation Segment struct
 * @param callGasLimit max gas to be spent on the call data.
 * @param callData the desired call data.
 */
struct UserOperationSegment {
    uint256 callGasLimit;
    bytes callData;
}

contract UserOperation is EntryPointTruster, IIntentStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Basic state and constants.
     */
    IEntryPoint private immutable _entryPoint;

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
     * Default receive function.
     */
    receive() external payable {}

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

        if (intent.intentData[segmentIndex].length > 0) {
            UserOperationSegment calldata dataSegment = parseIntentSegment(intent.intentData, segmentIndex);

            //execute calldata
            if (dataSegment.callData.length > 0) {
                Exec.call(intent.sender, 0, dataSegment.callData, dataSegment.callGasLimit);
                if (segmentIndex + 1 < intent.intentData.length && intent.intentData[segmentIndex + 1].length > 0) {
                    return context;
                }
            }
        }
        return "";
    }

    /**
     * Verifies the intent standard is for a given entry point contract (required for registration on the entry point).
     * @param entryPointContract the entry point contract.
     * @return flag indicating if the intent standard is for the given entry point.
     */
    function isIntentStandardForEntryPoint(IEntryPoint entryPointContract) external view override returns (bool) {
        return entryPointContract == _entryPoint;
    }

    function parseIntentSegment(bytes[] calldata intentData, uint256 segmentIndex)
        internal
        pure
        returns (UserOperationSegment calldata segment)
    {
        bytes calldata data = intentData[segmentIndex];
        assembly {
            segment := data.offset
        }
    }

    function testNothing() public {}
}
