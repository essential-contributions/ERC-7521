// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./UserIntent.sol";

interface IAccount {
    /**
     * Validate user's intent (typically a signature and nonce)
     * the entryPoint will continue to execute an intent solution only if this validation call returns successfully.
     * signature failure should be reported by returning SIG_VALIDATION_FAILED (1).
     * This allows making a "simulation call" without a valid signature
     * Other failures (e.g. nonce mismatch, or invalid signature format) should still revert to signal failure.
     *
     * @dev Must validate caller is the entryPoint.
     *      Must validate the signature, nonce, etc.
     * @param userInt the intent that is about to be solved.
     * @param userIntHash hash of the user's intent data. can be used as the basis for signature.
     * @return validationData packaged ValidationData structure. use `_packValidationData` and `_unpackValidationData` to encode and decode
     *      <20-byte> sigAuthorizer - 0 for valid signature, 1 to mark signature failure,
     *         otherwise, an address of an "authorizer" contract.
     *      <6-byte> validUntil - last timestamp this intent is valid. 0 for "indefinite"
     *      <6-byte> validAfter - first timestamp this intenr is valid
     *      If an account doesn't use time-range, it is enough to return SIG_VALIDATION_FAILED value (1) for signature failure.
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validateUserInt(UserIntent calldata userInt, bytes32 userIntHash)
        external
        returns (uint256 validationData);
}
