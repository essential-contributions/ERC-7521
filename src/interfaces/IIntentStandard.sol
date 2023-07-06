// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "./UserIntent.sol";

interface IIntentStandard {
    /**
     * Validate intent structure (typically just formatting)
     * the entryPoint will continue to execute an intent solution only if this validation call returns successfully.
     * This allows making a "simulation call" without valid timings, etc
     * Other failures (e.g. invalid format) should still revert to signal failure.
     *
     * @param userInt the intent that is about to be solved.
     * @return validationData packaged ValidationData structure. use `_packValidationData` and `_unpackValidationData` to encode and decode
     *      <20-byte> reserved - currently not used (fill with zeroes)
     *      <6-byte> validUntil - last timestamp this intent is valid. 0 for "indefinite"
     *      <6-byte> validAfter - first timestamp this intent is valid
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validateUserInt(UserIntent calldata userInt) external returns (uint256 validationData);

    function executeFirstPass(UserIntent calldata userInt, uint256 timestamp)
        external
        returns (bytes memory endContext);

    function executeSecondPass(UserIntent calldata userInt, uint256 timestamp, bytes memory context)
        external
        returns (bytes memory endContext);

    function verifyEndState(UserIntent calldata userInt, uint256 timestamp, bytes memory context) external;
}
