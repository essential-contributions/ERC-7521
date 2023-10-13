// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    EthRequireIntentCurve,
    evaluate,
    validate,
    parseCurveType,
    parseEvaluationType,
    isRelativeEvaluation,
    CurveType,
    EvaluationType
} from "../standards/ethRequire/EthRequireIntentCurve.sol";

library EthRequireIntentCurveLibHarness {
    function validateCurve(EthRequireIntentCurve calldata curve) public pure {
        validate(curve);
    }

    function evaluateCurve(EthRequireIntentCurve calldata curve, uint256 x) public pure returns (int256) {
        return evaluate(curve, x);
    }

    function parseCurveTypeOfCurve(EthRequireIntentCurve calldata curve) public pure returns (CurveType) {
        return parseCurveType(curve);
    }

    function parseEvaluationTypeOfCurve(EthRequireIntentCurve calldata curve) public pure returns (EvaluationType) {
        return parseEvaluationType(curve);
    }

    function isCurveRelativeEvaluation(EthRequireIntentCurve calldata curve) public pure returns (bool) {
        return isRelativeEvaluation(curve);
    }
}
