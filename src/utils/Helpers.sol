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

enum CurveType {
    CONSTANT,
    LINEAR,
    EXPONENTIAL,
    COUNT
}

enum EvaluationType {
    ABSOLUTE,
    RELATIVE,
    COUNT
}

uint256 constant FLAGS_EVAL_TYPE_OFFSET = 0;
uint256 constant FLAGS_CURVE_TYPE_OFFSET = 2;

uint16 constant FLAGS_EVAL_TYPE_MASK = 0x0003;
uint16 constant FLAGS_CURVE_TYPE_MASK = 0x00fc;

function evaluateConstantCurve(int256[] calldata curveParams) pure returns (int256 val) {
    val = curveParams[0];
}

function evaluateLinearCurve(int256[] calldata curveParams, uint256 x) pure returns (int256 val) {
    int256 sx = int256(x);
    //m*x + b, params [m,b,max]
    //negative "max" means to evaluate from right to left
    int256 m = curveParams[0];
    int256 b = curveParams[1];
    int256 max = int256(curveParams[2]);
    if (max < 0) {
        //negative "max" means to flip along the y-axis
        max = 0 - max;
        if (sx > max) sx = max;
        sx = max - sx;
    }
    if (sx > max) {
        sx = max;
    }
    val = (m * sx) + b;
}

function evaluateExponentialCurve(int256[] calldata curveParams, uint256 x) pure returns (int256 val) {
    int256 sx = int256(x);
    //m*(x**e) + b, params [m,b,e,max]
    //negative "max" means to evaluate from right to left
    int256 m = curveParams[0];
    int256 b = curveParams[1];
    uint256 e = uint256(curveParams[2]);
    int256 max = curveParams[3];
    if (max < 0) {
        //negative "max" means to flip along the y-axis
        max = 0 - max;
        if (sx > max) sx = max;
        sx = max - sx;
    }
    if (sx > max) {
        sx = max;
    }
    val = (m * (sx ** e)) + b;
}
