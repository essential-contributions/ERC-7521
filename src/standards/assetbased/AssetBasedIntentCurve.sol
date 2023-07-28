// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetType} from "./utils/AssetWrapper.sol";

//TODO: consider compressing all the flags into one uint256 for improved gas efficiency
//TODO: we may want to support signed numbers for the parameters

/**
 * Asset Curve struct
 * @param assetContract the address of the contract that controls the asset.
 * @param assetId the ID of the asset.
 * @param assetType the type of the asset (ETH, ERC-20, ERC-721, etc).
 * @param curveType the curve type (constant, linear, exponential).
 * @param evaluationType the evaluation type (relative, absolute).
 * @param params the parameters for the curve.
 */
struct AssetBasedIntentCurve {
    address assetContract;
    uint256 assetId;
    AssetType assetType;
    CurveType curveType;
    EvaluationType evaluationType;
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
    function validate(AssetBasedIntentCurve calldata curve) public pure {
        require(CurveType(0) <= curve.curveType && curve.curveType < CurveType.COUNT, "invalid curve type");
        require(AssetType(0) <= curve.assetType && curve.assetType < AssetType.COUNT, "invalid curve asset type");
        require(
            EvaluationType(0) <= curve.evaluationType && curve.evaluationType < EvaluationType.COUNT,
            "invalid curve eval type"
        );

        if (curve.curveType == CurveType.CONSTANT) {
            require(curve.params.length == 1, "invalid curve params");
        } else if (curve.curveType == CurveType.LINEAR) {
            require(curve.params.length == 3, "invalid curve params");
        } else if (curve.curveType == CurveType.EXPONENTIAL) {
            require(curve.params.length == 4, "invalid curve params");
            require(curve.params[2] >= 0, "invalid curve params"); //negative exponent
        }
    }

    // TODO: consider adding under/overflow custom errors
    function evaluate(AssetBasedIntentCurve calldata curve, uint256 x) public pure returns (int256 val) {
        int256 sx;
        unchecked {
            sx = int256(x);
            require(sx >= 0, "invalid x value");
        }
        if (curve.curveType == CurveType.CONSTANT) {
            val = curve.params[0];
        } else if (curve.curveType == CurveType.LINEAR) {
            //m*x + b, params [m,b,max]
            //negative "max" means to evaluate from right to left
            int256 m = curve.params[0];
            int256 b = curve.params[1];
            int256 max = curve.params[2];
            if (max < 0) {
                require(max > type(int256).min, "invalid max value");
                //negative "max" means to flip along the y-axis
                max = 0 - max;
                if (sx > max) sx = max;
                sx = max - sx;
            }
            if (sx > max) {
                sx = max;
            }
            unchecked {
                val = m * sx + b;
            }
        } else if (curve.curveType == CurveType.EXPONENTIAL) {
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
            unchecked {
                val = (m * (sx ** e)) + b;
            }
        }
    }

    function isRelativeEvaluation(AssetBasedIntentCurve calldata curve) public pure returns (bool) {
        return curve.evaluationType == EvaluationType.RELATIVE;
    }
}
