// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/standards/assetbased/AssetBasedIntentCurve.sol";
import "./TestEnvironment.sol";

contract AssetBasedIntentCurveTest is Test, TestEnvironment {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    AssetBasedIntentCurve internal _testConstantCurve = _curveETH(constantCurve(10), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testConstantRelativeCurve = _curveETH(constantCurve(10), EvaluationType.RELATIVE);
    AssetBasedIntentCurve internal _testLinearCurve = _curveETH(linearCurve(2, 10, 20, false), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testLinearFlippedCurve =
        _curveETH(linearCurve(2, 10, 20, true), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testExponentialCurve =
        _curveETH(exponentialCurve(2, 10, 2, 20, false), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testExponentialFlippedCurve =
        _curveETH(exponentialCurve(2, 10, 2, 20, true), EvaluationType.ABSOLUTE);

    function test_validate_constant() public view {
        _testConstantCurve.validate();
    }

    function test_validate_linear() public view {
        _testLinearCurve.validate();
        _testLinearFlippedCurve.validate();
    }

    function test_validate_exponential() public view {
        _testExponentialCurve.validate();
        _testExponentialFlippedCurve.validate();
    }

    function test_validate_invalidCurveType() public {
        _testConstantCurve.curveType = CurveType.COUNT;
        vm.expectRevert("invalid curve type");
        _testConstantCurve.validate();
    }

    function test_validate_invalidAssetType() public {
        _testConstantCurve.assetType = AssetType.COUNT;
        vm.expectRevert("invalid curve asset type");
        _testConstantCurve.validate();
    }

    function test_validate_invalidEvaluationType() public {
        _testConstantCurve.evaluationType = EvaluationType.COUNT;
        vm.expectRevert("invalid curve eval type");
        _testConstantCurve.validate();
    }

    function test_validate_invalidParamsConstant() public {
        _testConstantCurve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        _testConstantCurve.validate();
    }

    function test_validate_invalidParamsLinear() public {
        _testLinearCurve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        _testLinearCurve.validate();
    }

    function test_validate_invalidParamsExponential() public {
        _testExponentialCurve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        _testExponentialCurve.validate();
    }

    function test_validate_invalidParamsExponential2() public {
        _testExponentialCurve.params[2] = -1;
        vm.expectRevert("invalid curve params");
        _testExponentialCurve.validate();
    }

    function test_evaluate_constant() public {
        int256 value = _testConstantCurve.evaluate(10);
        assertEq(value, 10);
    }

    function test_evaluate_linear() public {
        int256 value = _testLinearCurve.evaluate(10);
        assertEq(value, 30);
    }

    function test_evaluate_linearMax() public {
        int256 value = _testLinearCurve.evaluate(30);
        assertEq(value, 50);
    }

    function test_evaluate_linearFlippedMax() public {
        int256 value = _testLinearFlippedCurve.evaluate(30);
        assertEq(value, 10);
    }

    function test_evaluate_exponential() public {
        int256 value = _testExponentialCurve.evaluate(1);
        assertEq(value, 12);
    }

    function test_evaluate_exponentialMax() public {
        int256 value = _testExponentialCurve.evaluate(30);
        assertEq(value, 810);
    }

    function test_evaluate_exponentialFlippedMax() public {
        int256 value = _testExponentialFlippedCurve.evaluate(30);
        assertEq(value, 10);
    }

    function test_isRelativeEvaluation() public view {
        assert(!_testConstantCurve.isRelativeEvaluation());
        assert(_testConstantRelativeCurve.isRelativeEvaluation());
    }
}
