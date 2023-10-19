// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import "forge-std/Test.sol";
import {EntryPointTruster} from "../core/EntryPointTruster.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {BaseStandard} from "../core/BaseStandard.sol";
import {Exec} from "../utils/Exec.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/**
 * Call Intent Segment struct
 * @param callData the intents desired call data.
 */
struct CallIntentSegment {
    bytes callData;
}

contract CallIntentStandard is IIntentStandard, BaseStandard {
    using IntentSolutionLib for IntentSolution;

    /**
     * Basic state and constants.
     */
    bytes32 internal constant CALL_INTENT_STANDARD_ID = 0;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Contract constructor.
     * @param entryPointContract the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPointContract) BaseStandard(entryPointContract) {}

    function standardId() public pure override returns (bytes32) {
        return CALL_INTENT_STANDARD_ID;
    }

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
            CallIntentSegment calldata dataSegment = parseIntentSegment(intent.intentData, segmentIndex);

            //execute calldata
            if (dataSegment.callData.length > 0) {
                Exec.callAndRevert(intent.sender, dataSegment.callData, REVERT_REASON_MAX_LEN);
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
        returns (CallIntentSegment calldata segment)
    {
        bytes calldata data = intentData[segmentIndex];
        assembly {
            segment := data.offset
        }
    }

    function testNothing() public {}
}
