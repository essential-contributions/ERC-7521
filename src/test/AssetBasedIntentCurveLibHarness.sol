// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    AssetBasedIntentCurve,
    evaluate,
    validate,
    parseAssetType,
    parseCurveType,
    parseEvaluationType,
    isRelativeEvaluation,
    CurveType,
    EvaluationType
} from "../standards/assetbased/AssetBasedIntentCurve.sol";
import {AssetType} from "../standards/assetbased/utils/AssetWrapper.sol";

library AssetBasedIntentCurveLibHarness {
    function validateCurve(AssetBasedIntentCurve calldata curve) public pure {
        validate(curve);
    }

    function evaluateCurve(AssetBasedIntentCurve calldata curve, uint256 x) public pure returns (int256) {
        return evaluate(curve, x);
    }

    function parseAssetTypeOfCurve(AssetBasedIntentCurve calldata curve) public pure returns (AssetType) {
        return parseAssetType(curve);
    }

    function parseCurveTypeOfCurve(AssetBasedIntentCurve calldata curve) public pure returns (CurveType) {
        return parseCurveType(curve);
    }

    function parseEvaluationTypeOfCurve(AssetBasedIntentCurve calldata curve) public pure returns (EvaluationType) {
        return parseEvaluationType(curve);
    }

    function isCurveRelativeEvaluation(AssetBasedIntentCurve calldata curve) public pure returns (bool) {
        return isRelativeEvaluation(curve);
    }
}
