// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IEntryPoint} from "./IEntryPoint.sol";
import {IntentSolution} from "./IntentSolution.sol";
import {UserIntent} from "./UserIntent.sol";

interface IIntentType {
    /**
     * Validate intent structure (typically just formatting).
     * @param intent the intent that is about to be solved.
     */
    function validateUserIntent(UserIntent calldata intent) external;

    /**
     * Performs part or all of the execution for an intent.
     * @param solution the full solution being executed.
     * @param executionIndex the current index of execution (used to get the UserIntent to execute for).
     * @param segmentIndex the current segment to execute for the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution.
     */
    function executeUserIntent(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes memory context
    ) external returns (bytes memory);

    /**
     * Verifies the intent type is for a given entry point contract (required for registration on the entry point).
     * @param entryPoint the entry point contract.
     * @return flag indicating if the intent type is for the given entry point.
     */
    function isIntentTypeForEntryPoint(IEntryPoint entryPoint) external returns (bool);
}
