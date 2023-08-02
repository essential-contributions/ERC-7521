// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

/**
 * returned data from validateUserIntent.
 * validateUserIntent returns a uint256, with is created by `_packedValidationData` and parsed by `_parseValidationData`
 * @param sigFailed - true for signature failure, false for success.
 * @param validAfter - this UserIntent is valid only after this timestamp.
 * @param validaUntil - this UserIntent is valid only up to this timestamp.
 */
struct ValidationData {
    bool sigFailed;
    uint48 validAfter;
    uint48 validUntil;
}

//extract sigFailed, validAfter, validUntil.
// also convert zero validUntil to type(uint48).max
function _parseValidationData(uint256 validationData) pure returns (ValidationData memory data) {
    bool sigFailed = uint8(validationData) == 1;
    uint48 validUntil = uint48(validationData >> 160);
    if (validUntil == 0) {
        validUntil = type(uint48).max;
    }
    uint48 validAfter = uint48(validationData >> (48 + 160));
    return ValidationData(sigFailed, validAfter, validUntil);
}

/**
 * helper to pack the return value for validateUserIntent
 * @param data - the ValidationData to pack
 */
function _packValidationData(ValidationData memory data) pure returns (uint256) {
    uint160 sigFailed = data.sigFailed ? 1 : 0;
    return sigFailed | (uint256(data.validUntil) << 160) | (uint256(data.validAfter) << (160 + 48));
}

/**
 * helper to pack the return value for validateUserIntent, when not using an aggregator
 * @param sigFailed - true for signature failure, false for success
 * @param validUntil last timestamp this UserIntent is valid (or zero for infinite)
 * @param validAfter first timestamp this UserIntent is valid
 */
function _packValidationData(bool sigFailed, uint48 validUntil, uint48 validAfter) pure returns (uint256) {
    return (sigFailed ? 1 : 0) | (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
}

/**
 * keccak function over calldata.
 * @dev copy calldata into memory, do keccak and drop allocated memory. Strangely, this is more efficient than letting solidity do it.
 */
function _calldataKeccak(bytes calldata data) pure returns (bytes32 ret) {
    assembly {
        let mem := mload(0x40)
        let len := data.length
        calldatacopy(mem, data.offset, len)
        ret := keccak256(mem, len)
    }
}
