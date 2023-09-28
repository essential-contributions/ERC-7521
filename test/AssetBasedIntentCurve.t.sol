// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import {
    validate,
    evaluate,
    generateFlags,
    parseAssetType,
    parseCurveType,
    parseEvaluationType,
    isRelativeEvaluation
} from "../src/standards/assetbased/AssetBasedIntentCurve.sol";

contract AssetBasedIntentCurveTest is TestEnvironment {
    function _constantCurve() private pure returns (AssetBasedIntentCurve memory) {
        return _curveETH(AssetBasedIntentCurveBuilder.constantCurve(10), EvaluationType.ABSOLUTE);
    }

    function _constantRelativeCurve() private pure returns (AssetBasedIntentCurve memory) {
        return _curveETH(AssetBasedIntentCurveBuilder.constantCurve(10), EvaluationType.RELATIVE);
    }

    function _linearCurve() private pure returns (AssetBasedIntentCurve memory) {
        return _curveETH(AssetBasedIntentCurveBuilder.linearCurve(2, 10, 20, false), EvaluationType.ABSOLUTE);
    }

    function _linearFlippedCurve() private pure returns (AssetBasedIntentCurve memory) {
        return _curveETH(AssetBasedIntentCurveBuilder.linearCurve(2, 10, 20, true), EvaluationType.ABSOLUTE);
    }

    function _exponentialCurve() private pure returns (AssetBasedIntentCurve memory) {
        return _curveETH(AssetBasedIntentCurveBuilder.exponentialCurve(2, 10, 2, 20, false), EvaluationType.ABSOLUTE);
    }

    function _exponentialFlippedCurve() private pure returns (AssetBasedIntentCurve memory) {
        return _curveETH(AssetBasedIntentCurveBuilder.exponentialCurve(2, 10, 2, 20, true), EvaluationType.ABSOLUTE);
    }

    function test_validate_constant() public pure {
        validate(_constantCurve());
    }

    function test_validate_linear() public pure {
        validate(_linearCurve());
        validate(_linearFlippedCurve());
    }

    function test_validate_exponential() public pure {
        validate(_exponentialCurve());
        validate(_exponentialFlippedCurve());
    }

    function test_validate_invalidCurveType() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.flags = generateFlags(AssetType.ETH, CurveType.COUNT, EvaluationType.ABSOLUTE);
        vm.expectRevert("invalid curve type");
        validate(_curve);
    }

    function test_validate_invalidAssetType() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.flags = generateFlags(AssetType.COUNT, CurveType.CONSTANT, EvaluationType.ABSOLUTE);
        vm.expectRevert("invalid curve asset type");
        validate(_curve);
    }

    function test_validate_invalidEvaluationType() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.flags = generateFlags(AssetType.ETH, CurveType.CONSTANT, EvaluationType.COUNT);
        vm.expectRevert("invalid curve eval type");
        validate(_curve);
    }

    function test_validate_invalidParamsConstant() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        validate(_curve);
    }

    function test_validate_invalidParamsLinear() public {
        AssetBasedIntentCurve memory _curve = _linearCurve();
        _curve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        validate(_curve);
    }

    function test_validate_invalidParamsExponential() public {
        AssetBasedIntentCurve memory _curve = _exponentialCurve();
        _curve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        validate(_curve);
    }

    function test_validate_invalidParamsExponential2() public {
        AssetBasedIntentCurve memory _curve = _exponentialCurve();
        _curve.params[2] = -1;
        vm.expectRevert("invalid curve params");
        validate(_curve);
    }

    function test_evaluate_constant() public {
        int256 value = evaluate(_constantCurve(), 10);
        assertEq(value, 10);
    }

    function test_evaluate_linear() public {
        int256 value = evaluate(_linearCurve(), 10);
        assertEq(value, 30);
    }

    function test_evaluate_linearMax() public {
        int256 value = evaluate(_linearCurve(), 30);
        assertEq(value, 50);
    }

    function test_evaluate_linearFlippedMax() public {
        int256 value = evaluate(_linearFlippedCurve(), 30);
        assertEq(value, 10);
    }

    function test_evaluate_exponential() public {
        int256 value = evaluate(_exponentialCurve(), 1);
        assertEq(value, 12);
    }

    function test_evaluate_exponentialMax() public {
        int256 value = evaluate(_exponentialCurve(), 30);
        assertEq(value, 810);
    }

    function test_evaluate_exponentialFlippedMax() public {
        int256 value = evaluate(_exponentialFlippedCurve(), 30);
        assertEq(value, 10);
    }

    function test_assetType() public {
        assertEq(abi.encode(parseAssetType(_constantCurve())), abi.encode(AssetType.ETH));
    }

    function test_curveType() public {
        assertEq(abi.encode(parseCurveType(_constantCurve())), abi.encode(CurveType.CONSTANT));
    }

    function test_evaluationType() public {
        assertEq(abi.encode(parseEvaluationType(_constantCurve())), abi.encode(EvaluationType.ABSOLUTE));
        assertEq(abi.encode(parseEvaluationType(_constantRelativeCurve())), abi.encode(EvaluationType.RELATIVE));
    }

    function test_isRelativeEvaluation() public pure {
        assert(!isRelativeEvaluation(_constantCurve()));
        assert(isRelativeEvaluation(_constantRelativeCurve()));
    }
}
