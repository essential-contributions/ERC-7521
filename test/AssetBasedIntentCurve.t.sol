// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/standards/assetbased/AssetBasedIntentCurve.sol";
import "./TestEnvironment.sol";

contract AssetBasedIntentCurveTest is Test, TestEnvironment {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    AssetBasedIntentCurve internal _testConstantCurve = _curveETH(constantCurve(10), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testConstantRelativeCurve = _curveETH(constantCurve(10), EvaluationType.RELATIVE);
    AssetBasedIntentCurve internal _testLinearCurve = _curveETH(linearCurve(2, 10, 20), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testLinearFlippedCurve = _curveETH(linearCurve(2, 10, -20), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testExponentialCurve =
        _curveETH(exponentialCurve(2, 10, 2, 20), EvaluationType.ABSOLUTE);
    AssetBasedIntentCurve internal _testExponentialFlippedCurve =
        _curveETH(exponentialCurve(2, 10, 2, -20), EvaluationType.ABSOLUTE);

    function test_validate_constant(int256 curveParam) public pure {
        _curveETH(constantCurve(curveParam), EvaluationType.ABSOLUTE).validate();
    }

    function test_validate_linear(int256 m, int256 b, int256 max) public pure {
        _curveETH(linearCurve(m, b, max), EvaluationType.ABSOLUTE).validate();
    }

    function test_validate_exponential(int256 m, int256 b, int256 e, int256 max) public pure {
        vm.assume(e >= 0);
        _curveETH(exponentialCurve(m, b, e, max), EvaluationType.ABSOLUTE).validate();
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

    function test_evaluate_constant(int256 curveParam, uint256 at) public {
        vm.assume(at <= uint256(type(int256).max));
        int256 result = _curveETH(constantCurve(curveParam), EvaluationType.ABSOLUTE).evaluate(at);
        assertEq(result, curveParam);
    }

    function test_evaluate_linear(int256 m, int256 b, int256 max, uint256 at) public {
        vm.assume(at <= uint256(type(int256).max));
        vm.assume(0 <= max);
        vm.assume(at <= uint256(max));
        int256 result = _curveETH(linearCurve(m, b, max), EvaluationType.ABSOLUTE).evaluate(at);
        int256 expectedResult;
        unchecked {
            expectedResult = (m * int256(at)) + b;
        }
        assertEq(result, expectedResult);
    }

    function test_evaluate_linear2(int256 m, int256 b, int256 max, uint256 at) public {
        vm.assume(at <= uint256(type(int256).max));
        vm.assume(0 <= max);
        vm.assume(at > uint256(max));
        int256 result = _curveETH(linearCurve(m, b, max), EvaluationType.ABSOLUTE).evaluate(at);
        int256 expectedResult;
        unchecked {
            expectedResult = (m * max) + b;
        }
        assertEq(result, expectedResult);
    }

    function test_evaluate_linear3(int256 m, int256 b, int256 max, uint256 at) public {
        vm.assume(at <= uint256(type(int256).max));
        vm.assume(max > type(int256).min);
        vm.assume(0 > max);
        vm.assume(int256(at) <= -max);
        int256 result = _curveETH(linearCurve(m, b, max), EvaluationType.ABSOLUTE).evaluate(at);
        int256 expectedResult;
        unchecked {
            expectedResult = (m * (-max - int256(at))) + b;
        }
        assertEq(result, expectedResult);
    }

    function test_evaluate_linear4(int256 m, int256 b, int256 max, uint256 at) public {
        // TODO: max is negative and at > -max
    }

    function test_evaluationPointOverflow() public {
        uint256 at = uint256(type(int256).max) + 1;
        vm.expectRevert("invalid x value");
        _curveETH(linearCurve(0, 0, 0), EvaluationType.ABSOLUTE).evaluate(at);
    }

    function test_maxUnderflow() public {
        int256 max = type(int256).min;
        vm.expectRevert("invalid max value");
        _curveETH(linearCurve(0, 0, max), EvaluationType.ABSOLUTE).evaluate(0);
    }

    function test_isRelativeEvaluation() public view {
        assert(!_testConstantCurve.isRelativeEvaluation());
        assert(_testConstantRelativeCurve.isRelativeEvaluation());
    }
}
