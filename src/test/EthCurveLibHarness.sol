// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {
    EthCurve,
    evaluate,
    validate,
    parseCurveType,
    parseEvaluationType,
    isRelativeEvaluation,
    CurveType,
    EvaluationType
} from "../utils/curves/EthCurve.sol";

library EthCurveLibHarness {
    function validateCurve(EthCurve calldata curve) public pure {
        validate(curve);
    }

    function evaluateCurve(EthCurve calldata curve, uint256 x) public pure returns (int256) {
        return evaluate(curve, x);
    }

    function parseCurveTypeOfCurve(EthCurve calldata curve) public pure returns (CurveType) {
        return parseCurveType(curve);
    }

    function parseEvaluationTypeOfCurve(EthCurve calldata curve) public pure returns (EvaluationType) {
        return parseEvaluationType(curve);
    }

    function isCurveRelativeEvaluation(EthCurve calldata curve) public pure returns (bool) {
        return isRelativeEvaluation(curve);
    }

    function testNothing() public {}
}
