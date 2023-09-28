// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";

contract AssetBasedIntentCurveTest is TestEnvironment {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

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
        _constantCurve().validate();
    }

    function test_validate_linear() public pure {
        _linearCurve().validate();
        _linearFlippedCurve().validate();
    }

    function test_validate_exponential() public pure {
        _exponentialCurve().validate();
        _exponentialFlippedCurve().validate();
    }

    function test_validate_invalidCurveType() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.flags = AssetBasedIntentCurveLib.generateFlags(AssetType.ETH, CurveType.COUNT, EvaluationType.ABSOLUTE);
        vm.expectRevert("invalid curve type");
        _curve.validate();
    }

    function test_validate_invalidAssetType() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.flags =
            AssetBasedIntentCurveLib.generateFlags(AssetType.COUNT, CurveType.CONSTANT, EvaluationType.ABSOLUTE);
        vm.expectRevert("invalid curve asset type");
        _curve.validate();
    }

    function test_validate_invalidEvaluationType() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.flags = AssetBasedIntentCurveLib.generateFlags(AssetType.ETH, CurveType.CONSTANT, EvaluationType.COUNT);
        vm.expectRevert("invalid curve eval type");
        _curve.validate();
    }

    function test_validate_invalidParamsConstant() public {
        AssetBasedIntentCurve memory _curve = _constantCurve();
        _curve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        _curve.validate();
    }

    function test_validate_invalidParamsLinear() public {
        AssetBasedIntentCurve memory _curve = _linearCurve();
        _curve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        _curve.validate();
    }

    function test_validate_invalidParamsExponential() public {
        AssetBasedIntentCurve memory _curve = _exponentialCurve();
        _curve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        _curve.validate();
    }

    function test_validate_invalidParamsExponential2() public {
        AssetBasedIntentCurve memory _curve = _exponentialCurve();
        _curve.params[2] = -1;
        vm.expectRevert("invalid curve params");
        _curve.validate();
    }

    function test_evaluate_constant() public {
        int256 value = _constantCurve().evaluate(10);
        assertEq(value, 10);
    }

    function test_evaluate_linear() public {
        int256 value = _linearCurve().evaluate(10);
        assertEq(value, 30);
    }

    function test_evaluate_linearMax() public {
        int256 value = _linearCurve().evaluate(30);
        assertEq(value, 50);
    }

    function test_evaluate_linearFlippedMax() public {
        int256 value = _linearFlippedCurve().evaluate(30);
        assertEq(value, 10);
    }

    function test_evaluate_exponential() public {
        int256 value = _exponentialCurve().evaluate(1);
        assertEq(value, 12);
    }

    function test_evaluate_exponentialMax() public {
        int256 value = _exponentialCurve().evaluate(30);
        assertEq(value, 810);
    }

    function test_evaluate_exponentialFlippedMax() public {
        int256 value = _exponentialFlippedCurve().evaluate(30);
        assertEq(value, 10);
    }

    function test_assetType() public {
        assertEq(abi.encode(_constantCurve().assetType()), abi.encode(AssetType.ETH));
    }

    function test_curveType() public {
        assertEq(abi.encode(_constantCurve().curveType()), abi.encode(CurveType.CONSTANT));
    }

    function test_evaluationType() public {
        assertEq(abi.encode(_constantCurve().evaluationType()), abi.encode(EvaluationType.ABSOLUTE));
        assertEq(abi.encode(_constantRelativeCurve().evaluationType()), abi.encode(EvaluationType.RELATIVE));
    }

    function test_isRelativeEvaluation() public pure {
        assert(!_constantCurve().isRelativeEvaluation());
        assert(_constantRelativeCurve().isRelativeEvaluation());
    }
}
