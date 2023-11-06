// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

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

/**
 * Generate flags from curve type and evaluation type.
 */
function generateFlags(CurveType curve, EvaluationType eval) pure returns (uint48) {
    return uint48((uint256(curve) << FLAGS_CURVE_TYPE_OFFSET) | (uint256(eval) << FLAGS_EVAL_TYPE_OFFSET));
}

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
