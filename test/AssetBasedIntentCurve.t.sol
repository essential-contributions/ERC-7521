// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import "../src/standards/assetbased/AssetBasedIntentCurve.sol";
import "./TestUtil.sol";

// TODO: lines that check the validity of enums are unreachable
contract AssetBasedIntentCurveTest is Test, TestUtil {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    function test_validate_constantAbsolute() public view {
        constantAbsoluteCurve.validate();
    }

    function test_validate_constantRelative() public view {
        constantRelativeCurve.validate();
    }

    function test_validate_linearAbsolute() public view {
        linearAbsoluteCurve.validate();
    }

    function test_validate_linearRelative() public view {
        linearRelativeCurve.validate();
    }

    function test_validate_exponentialAbsolute() public view {
        exponentialAbsoluteCurve.validate();
    }

    function test_validate_exponentialRelative() public view {
        exponentialRelativeCurve.validate();
    }

    function test_validate_invalidParamsConstant() public {
        constantAbsoluteCurve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        constantAbsoluteCurve.validate();
    }

    function test_validate_invalidParamsLinear() public {
        linearAbsoluteCurve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        linearAbsoluteCurve.validate();
    }

    function test_validate_invalidParamsExponential() public {
        exponentialAbsoluteCurve.params = new int256[](0);
        vm.expectRevert("invalid curve params");
        exponentialAbsoluteCurve.validate();
    }

    function test_validate_invalidParamsExponential2() public {
        exponentialAbsoluteCurve.params[2] = -1;
        vm.expectRevert("invalid curve params");
        exponentialAbsoluteCurve.validate();
    }

    function test_evaluate_constant() public {
        int256 value = constantAbsoluteCurve.evaluate(10);
        assertEq(value, 10);
    }

    function test_evaluate_linear() public {
        int256 value = linearAbsoluteCurve.evaluate(10);
        assertEq(value, 30);
    }

    function test_evaluate_linearMax() public {
        int256 value = linearAbsoluteCurve.evaluate(30);
        assertEq(value, 50);
    }

    function test_evaluate_exponential() public {
        int256 value = exponentialAbsoluteCurve.evaluate(10);
        assertEq(value, 210);
    }

    function test_evaluate_exponentialMax() public {
        int256 value = exponentialAbsoluteCurve.evaluate(30);
        assertEq(value, 810);
    }

    function test_isRelativeEvaluation() public view {
        assert(constantRelativeCurve.isRelativeEvaluation());
        assert(!constantAbsoluteCurve.isRelativeEvaluation());
    }
}
