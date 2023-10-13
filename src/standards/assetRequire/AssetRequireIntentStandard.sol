// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {AssetCurve, isRelativeEvaluation, validate, evaluate, parseAssetType} from "../../utils/AssetCurve.sol";
import {AssetRequireIntentSegment} from "./AssetRequireIntentSegment.sol";
import {AssetType, _balanceOf, _transfer} from "../../utils/AssetWrapper.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../../interfaces/IIntentStandard.sol";
import {UserIntent} from "../../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../../interfaces/IntentSolution.sol";
import {EntryPointTruster} from "../../core/EntryPointTruster.sol";
import {Exec, RevertReason} from "../../utils/Exec.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract AssetRequireIntentStandard is EntryPointTruster, IIntentStandard {
    using IntentSolutionLib for IntentSolution;
    using RevertReason for bytes;

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
     * Validate intent segment structure (typically just formatting).
     * @param segmentData the intent segment that is about to be solved.
     */
    function validateIntentSegment(bytes calldata segmentData) external pure {
        if (segmentData.length > 0) {
            AssetRequireIntentSegment calldata segment = parseIntentSegment(segmentData);
            validate(segment.assetRequirement);
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
    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) external returns (bytes memory) {
        UserIntent calldata intent = solution.intents[solution.getIntentIndex(executionIndex)];
        if (intent.intentData[segmentIndex].length > 0) {
            if (segmentIndex + 1 < intent.intentData.length && intent.intentData[segmentIndex + 1].length > 0) {
                return context;
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

    function parseIntentSegment(bytes calldata segmentData)
        internal
        pure
        returns (AssetRequireIntentSegment calldata segment)
    {
        assembly {
            segment := segmentData.offset
        }
    }
}
