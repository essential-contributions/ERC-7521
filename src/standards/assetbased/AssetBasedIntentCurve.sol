// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {AssetType} from "./utils/AssetWrapper.sol";

/**
 * Asset Curve struct
 * @param assetId the ID of the asset.
 * @param assetContract the address of the contract that controls the asset.
 * @param flags flags for asset type, curve type and evaluation type.
 *   The top 8 bytes are unused and the bottom 4 bytes are arranged as follows:
 *   reserved    reserved    asset type  curve/eval type
 *   [xxxx xxxx] [xxxx xxxx] [aaaa aaaa] [cccc ccee]
 * @param params the parameters for the curve.
 */
struct AssetBasedIntentCurve {
    uint256 assetId;
    address assetContract;
    uint96 flags;
    int256[] params;
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
uint256 constant FLAGS_ASSET_TYPE_OFFSET = 8;

uint16 constant FLAGS_EVAL_TYPE_MASK = 0x0003;
uint16 constant FLAGS_CURVE_TYPE_MASK = 0x00fc;
uint16 constant FLAGS_ASSET_TYPE_MASK = 0xff00;

function validate(AssetBasedIntentCurve calldata curve) pure {
    require(parseCurveType(curve) < CurveType.COUNT, "invalid curve type");
    require(parseAssetType(curve) < AssetType.COUNT, "invalid curve asset type");
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

function evaluate(AssetBasedIntentCurve calldata curve, uint256 x) pure returns (int256 val) {
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

function parseAssetType(AssetBasedIntentCurve calldata curve) pure returns (AssetType) {
    return AssetType((uint16(curve.flags) & FLAGS_ASSET_TYPE_MASK) >> FLAGS_ASSET_TYPE_OFFSET);
}

function parseCurveType(AssetBasedIntentCurve calldata curve) pure returns (CurveType) {
    return CurveType((uint16(curve.flags) & FLAGS_CURVE_TYPE_MASK) >> FLAGS_CURVE_TYPE_OFFSET);
}

function parseEvaluationType(AssetBasedIntentCurve calldata curve) pure returns (EvaluationType) {
    return EvaluationType((uint16(curve.flags) & FLAGS_EVAL_TYPE_MASK) >> FLAGS_EVAL_TYPE_OFFSET);
}

function isRelativeEvaluation(AssetBasedIntentCurve calldata curve) pure returns (bool) {
    return parseEvaluationType(curve) == EvaluationType.RELATIVE;
}

function generateFlags(AssetType asset, CurveType curve, EvaluationType eval) pure returns (uint96) {
    return uint96(
        (uint256(asset) << FLAGS_ASSET_TYPE_OFFSET) | (uint256(curve) << FLAGS_CURVE_TYPE_OFFSET)
            | (uint256(eval) << FLAGS_EVAL_TYPE_OFFSET)
    );
}
