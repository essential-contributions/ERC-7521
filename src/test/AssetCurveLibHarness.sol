// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    AssetCurve,
    evaluate,
    validate,
    parseAssetType,
    parseCurveType,
    parseEvaluationType,
    isRelativeEvaluation,
    CurveType,
    EvaluationType
} from "../utils/AssetCurve.sol";
import {AssetType} from "../utils/AssetWrapper.sol";

library AssetCurveLibHarness {
    function validateCurve(AssetCurve calldata curve) public pure {
        validate(curve);
    }

    function evaluateCurve(AssetCurve calldata curve, uint256 x) public pure returns (int256) {
        return evaluate(curve, x);
    }

    function parseAssetTypeOfCurve(AssetCurve calldata curve) public pure returns (AssetType) {
        return parseAssetType(curve);
    }

    function parseCurveTypeOfCurve(AssetCurve calldata curve) public pure returns (CurveType) {
        return parseCurveType(curve);
    }

    function parseEvaluationTypeOfCurve(AssetCurve calldata curve) public pure returns (EvaluationType) {
        return parseEvaluationType(curve);
    }

    function isCurveRelativeEvaluation(AssetCurve calldata curve) public pure returns (bool) {
        return isRelativeEvaluation(curve);
    }
}
