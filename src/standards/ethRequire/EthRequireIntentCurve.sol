// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {
    CurveType,
    EvaluationType,
    FLAGS_CURVE_TYPE_MASK,
    FLAGS_CURVE_TYPE_OFFSET,
    FLAGS_EVAL_TYPE_MASK,
    FLAGS_EVAL_TYPE_OFFSET
} from "../../utils/Helpers.sol";

/**
 * Eth Require Intent Curve struct
 * @param flags flags for asset type, curve type and evaluation type.
 *   The top 8 bytes are unused and the bottom 4 bytes are arranged as follows:
 *   reserved    reserved    reserved    curve/eval type
 *   [xxxx xxxx] [xxxx xxxx] [xxxx xxxx] [cccc ccee]
 * @param params the parameters for the curve.
 */
struct EthRequireIntentCurve {
    uint96 flags;
    int256[] params;
}

/**
 * Validate EthRequireIntentCurve params and flags.
 */
function validate(EthRequireIntentCurve calldata curve) pure {
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
function evaluate(EthRequireIntentCurve calldata curve, uint256 x) pure returns (int256 val) {
    int256 sx = int256(x);
    if (parseCurveType(curve) == CurveType.CONSTANT) {
        val = curve.params[0];
    } else if (parseCurveType(curve) == CurveType.LINEAR) {
        //m*x + b, params [m,b,max]
        //negative "max" means to evaluate from right to left
        int256 m = curve.params[0];
        int256 b = curve.params[1];
        int256 max = int256(curve.params[2]);
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
    } else if (parseCurveType(curve) == CurveType.EXPONENTIAL) {
        //m*(x**e) + b, params [m,b,e,max]
        //negative "max" means to evaluate from right to left
        int256 m = curve.params[0];
        int256 b = curve.params[1];
        uint256 e = uint256(curve.params[2]);
        int256 max = curve.params[3];
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
}

/**
 * Parse curve type from flag, i.e. rightmost 6 bits with offset 2
 */
function parseCurveType(EthRequireIntentCurve calldata curve) pure returns (CurveType) {
    return CurveType((uint16(curve.flags) & FLAGS_CURVE_TYPE_MASK) >> FLAGS_CURVE_TYPE_OFFSET);
}

/**
 * Parse evaluation type from flag, i.e. rightmost 2 bits
 */
function parseEvaluationType(EthRequireIntentCurve calldata curve) pure returns (EvaluationType) {
    return EvaluationType((uint16(curve.flags) & FLAGS_EVAL_TYPE_MASK) >> FLAGS_EVAL_TYPE_OFFSET);
}

/**
 * Check if curve should be evaluated relatively.
 */
function isRelativeEvaluation(EthRequireIntentCurve calldata curve) pure returns (bool) {
    return parseEvaluationType(curve) == EvaluationType.RELATIVE;
}

/**
 * Generate flags from asset type, curve type and evaluation type.
 */
function generateEthRequireFlags(CurveType curve, EvaluationType eval) pure returns (uint96) {
    return uint96((uint256(curve) << FLAGS_CURVE_TYPE_OFFSET) | (uint256(eval) << FLAGS_EVAL_TYPE_OFFSET));
}
