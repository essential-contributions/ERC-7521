// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    AssetBasedIntentCurve,
    AssetBasedIntentCurveLib,
    CurveType,
    EvaluationType
} from "../standards/assetbased/AssetBasedIntentCurve.sol";
import {AssetType} from "../standards/assetbased/utils/AssetWrapper.sol";

library AssetBasedIntentCurveLibHarness {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    function validate(AssetBasedIntentCurve calldata curve) public pure {
        curve.validate();
    }

    function evaluate(AssetBasedIntentCurve calldata curve, uint256 x) public pure returns (int256) {
        return curve.evaluate(x);
    }

    function assetType(AssetBasedIntentCurve calldata curve) public pure returns (AssetType) {
        return curve.assetType();
    }

    function curveType(AssetBasedIntentCurve calldata curve) public pure returns (CurveType) {
        return curve.curveType();
    }

    function evaluationType(AssetBasedIntentCurve calldata curve) public pure returns (EvaluationType) {
        return curve.evaluationType();
    }

    function isRelativeEvaluation(AssetBasedIntentCurve calldata curve) public pure returns (bool) {
        return curve.isRelativeEvaluation();
    }

    function generateFlags(AssetType asset, CurveType curve, EvaluationType evaluation) public pure returns (uint96) {
        return AssetBasedIntentCurveLib.generateFlags(asset, curve, evaluation);
    }
}
