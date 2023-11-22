// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {CurveType} from "../../../../src/utils/Helpers.sol";

/**
 * @title CurveBuilder
 * Utility functions helpful for building a curve.
 */
library CurveBuilder {
    /**
     * @dev Helper function to generate curve parameters for a constant curve.
     * @param amount The constant value for the curve.
     * @return params The array containing the curve parameters.
     */
    function constantCurve(int256 amount) public pure returns (int256[] memory) {
        int256[] memory params = new int256[](1);
        params[0] = amount;
        return params;
    }

    /**
     * @dev Helper function to generate curve parameters for a linear curve.
     * @param m The slope of the linear curve.
     * @param b The y-intercept of the linear curve.
     * @param max The maximum x value for the curve.
     * @param flipY Boolean flag to indicate if the curve should be evaluated from right to left.
     * @return params The array containing the curve parameters.
     */
    function linearCurve(int256 m, int256 b, uint256 max, bool flipY) public pure returns (int256[] memory) {
        int256[] memory params = new int256[](3);
        int256 signedMax = int256(max);
        if (flipY) signedMax = -signedMax;
        params[0] = m;
        params[1] = b;
        params[2] = signedMax;
        return params;
    }

    /**
     * @dev Helper function to generate curve parameters for an exponential curve.
     * @param m The multiplier for the exponential curve.
     * @param b The base for the exponential curve.
     * @param e The exponent for the exponential curve.
     * @param max The maximum x value for the curve.
     * @param flipY Boolean flag to indicate if the curve should be evaluated from right to left.
     * @return params The array containing the curve parameters.
     */
    function exponentialCurve(int256 m, int256 b, int256 e, uint256 max, bool flipY)
        public
        pure
        returns (int256[] memory)
    {
        int256[] memory params = new int256[](4);
        int256 signedMax = int256(max);
        if (flipY) signedMax = -signedMax;
        params[0] = m;
        params[1] = b;
        params[2] = e;
        params[3] = signedMax;
        return params;
    }

    /**
     * Helper function to determine the type of the curve based on its parameters.
     */
    function getCurveType(int256[] memory params) public pure returns (CurveType) {
        if (params.length == 4) return CurveType.EXPONENTIAL;
        if (params.length == 3) return CurveType.LINEAR;
        return CurveType.CONSTANT;
    }

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
