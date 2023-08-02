// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetType} from "./utils/AssetWrapper.sol";

/**
 * Asset Curve struct
 * @param assetContract the address of the contract that controls the asset.
 * @param assetId the ID of the asset.
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

/**
 * Utility functions helpful when working with AssetBasedIntentCurve structs.
 */
library AssetBasedIntentCurveLib {
    uint256 private constant FLAGS_EVAL_TYPE_OFFSET = 0;
    uint256 private constant FLAGS_CURVE_TYPE_OFFSET = 2;
    uint256 private constant FLAGS_ASSET_TYPE_OFFSET = 8;

    uint16 private constant FLAGS_EVAL_TYPE_MASK = 0x0003;
    uint16 private constant FLAGS_CURVE_TYPE_MASK = 0x00fc;
    uint16 private constant FLAGS_ASSET_TYPE_MASK = 0xff00;

    function validate(AssetBasedIntentCurve calldata curve) public pure {
        require(curveType(curve) < CurveType.COUNT, "invalid curve type");
        require(assetType(curve) < AssetType.COUNT, "invalid curve asset type");
        require(evaluationType(curve) < EvaluationType.COUNT, "invalid curve eval type");

        if (curveType(curve) == CurveType.CONSTANT) {
            require(curve.params.length == 1, "invalid curve params");
        } else if (curveType(curve) == CurveType.LINEAR) {
            require(curve.params.length == 3, "invalid curve params");
        } else if (curveType(curve) == CurveType.EXPONENTIAL) {
            require(curve.params.length == 4, "invalid curve params");
            require(curve.params[2] >= 0, "invalid curve params"); //negative exponent
        } else {
            revert("unknown curve type");
        }
    }

    function evaluate(AssetBasedIntentCurve calldata curve, uint256 x) public pure returns (int256 val) {
        int256 sx = int256(x);
        if (curveType(curve) == CurveType.CONSTANT) {
            val = curve.params[0];
        } else if (curveType(curve) == CurveType.LINEAR) {
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
        } else if (curveType(curve) == CurveType.EXPONENTIAL) {
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
        } else {
            val = 0;
        }
    }

    function assetType(AssetBasedIntentCurve calldata curve) public pure returns (AssetType) {
        return AssetType((uint16(curve.flags) & FLAGS_ASSET_TYPE_MASK) >> FLAGS_ASSET_TYPE_OFFSET);
    }

    function curveType(AssetBasedIntentCurve calldata curve) public pure returns (CurveType) {
        return CurveType((uint16(curve.flags) & FLAGS_CURVE_TYPE_MASK) >> FLAGS_CURVE_TYPE_OFFSET);
    }

    function evaluationType(AssetBasedIntentCurve calldata curve) public pure returns (EvaluationType) {
        return EvaluationType((uint16(curve.flags) & FLAGS_EVAL_TYPE_MASK) >> FLAGS_EVAL_TYPE_OFFSET);
    }

    function isRelativeEvaluation(AssetBasedIntentCurve calldata curve) public pure returns (bool) {
        return evaluationType(curve) == EvaluationType.RELATIVE;
    }

    function generateFlags(AssetType asset, CurveType curve, EvaluationType eval) public pure returns (uint96) {
        return uint96(
            (uint256(asset) << FLAGS_ASSET_TYPE_OFFSET) | (uint256(curve) << FLAGS_CURVE_TYPE_OFFSET)
                | (uint256(eval) << FLAGS_EVAL_TYPE_OFFSET)
        );
    }
}
