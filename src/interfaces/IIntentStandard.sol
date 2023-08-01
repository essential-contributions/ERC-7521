// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IEntryPoint} from "./IEntryPoint.sol";
import {UserIntent} from "./UserIntent.sol";

interface IIntentStandard {
    /**
     * Validate intent structure (typically just formatting).
     * @param userInt the intent that is about to be solved.
     */
    function validateUserInt(UserIntent calldata userInt) external;

    /**
     * Performs part or all of the execution for an intent.
     * @param userInt the intent to execute.
     * @param timestamp the time at which to evaluate the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     */
    function executeUserIntent(UserIntent calldata userInt, uint256 timestamp, bytes memory context)
        external
        returns (bytes memory);

    /**
     * Verifies the intent standard is for a given entry point contract (required for registration on the entry point).
     * @param entryPoint the entry point contract.
     * @return flag indicating if the intent standard is for the given entry point.
     */
    function isIntentStandardForEntryPoint(IEntryPoint entryPoint) external returns (bool);
}
