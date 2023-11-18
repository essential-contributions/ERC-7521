// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {
    Erc20Curve,
    evaluate,
    validate,
    parseCurveType,
    parseEvaluationType,
    isRelativeEvaluation,
    CurveType,
    EvaluationType
} from "../../../../src/utils/curves/Erc20Curve.sol";

library Erc20CurveLibHarness {
    function validateCurve(Erc20Curve calldata curve) public pure {
        validate(curve);
    }

    function evaluateCurve(Erc20Curve calldata curve, uint256 x) public pure returns (int256) {
        return evaluate(curve, x);
    }

    function parseCurveTypeOfCurve(Erc20Curve calldata curve) public pure returns (CurveType) {
        return parseCurveType(curve);
    }

    function parseEvaluationTypeOfCurve(Erc20Curve calldata curve) public pure returns (EvaluationType) {
        return parseEvaluationType(curve);
    }

    function isCurveRelativeEvaluation(Erc20Curve calldata curve) public pure returns (bool) {
        return isRelativeEvaluation(curve);
    }
    
    /** 
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
