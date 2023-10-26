// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {
    CurveType,
    EvaluationType,
    FLAGS_CURVE_TYPE_MASK,
    FLAGS_CURVE_TYPE_OFFSET,
    FLAGS_EVAL_TYPE_MASK,
    FLAGS_EVAL_TYPE_OFFSET,
    evaluateConstantCurve,
    evaluateLinearCurve,
    evaluateExponentialCurve
} from "../Helpers.sol";

/**
 * Erc20 Curve struct
 * @param assetContract the address of the contract that controls the asset.
 * @param flags flags for asset type, curve type and evaluation type.
 *   The top 8 bytes are unused and the bottom 4 bytes are arranged as follows:
 *   reserved    reserved    reserved    curve/eval type
 *   [xxxx xxxx] [xxxx xxxx] [xxxx xxxx] [cccc ccee]
 * @param params the parameters for the curve.
 */
struct Erc20Curve {
    address erc20Contract;
    uint96 flags;
    int256[] params;
}

/**
 * Validate Erc20Curve params and flags.
 */
function validate(Erc20Curve calldata curve) pure {
    require(parseCurveType(curve) < CurveType.COUNT, "invalid curve type");
    require(parseEvaluationType(curve) < EvaluationType.COUNT, "invalid curve eval type");

    if (parseCurveType(curve) == CurveType.CONSTANT) {
        require(curve.params.length == 1, "invalid curve params");
    } else if (parseCurveType(curve) == CurveType.LINEAR) {
        require(curve.params.length == 3, "invalid curve params");
    } else if (parseCurveType(curve) == CurveType.EXPONENTIAL) {
        require(curve.params.length == 4, "invalid curve params");
        require(curve.params[2] >= 0, "invalid curve params"); //negative exponent
    }
}

/**
 * Evaluate curve at given point.
 */
function evaluate(Erc20Curve calldata curve, uint256 x) pure returns (int256 val) {
    if (parseCurveType(curve) == CurveType.CONSTANT) {
        val = evaluateConstantCurve(curve.params);
    } else if (parseCurveType(curve) == CurveType.LINEAR) {
        val = evaluateLinearCurve(curve.params, x);
    } else if (parseCurveType(curve) == CurveType.EXPONENTIAL) {
        val = evaluateExponentialCurve(curve.params, x);
    }
}

/**
 * Parse curve type from flag, i.e. rightmost 6 bits with offset 2
 */
function parseCurveType(Erc20Curve calldata curve) pure returns (CurveType) {
    return CurveType((uint16(curve.flags) & FLAGS_CURVE_TYPE_MASK) >> FLAGS_CURVE_TYPE_OFFSET);
}

/**
 * Parse evaluation type from flag, i.e. rightmost 2 bits
 */
function parseEvaluationType(Erc20Curve calldata curve) pure returns (EvaluationType) {
    return EvaluationType((uint16(curve.flags) & FLAGS_EVAL_TYPE_MASK) >> FLAGS_EVAL_TYPE_OFFSET);
}

/**
 * Check if curve should be evaluated relatively.
 */
function isRelativeEvaluation(Erc20Curve calldata curve) pure returns (bool) {
    return parseEvaluationType(curve) == EvaluationType.RELATIVE;
}
