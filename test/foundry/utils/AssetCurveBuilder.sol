// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {AssetCurve, generateAssetFlags, CurveType, EvaluationType} from "../../../src/utils/AssetCurve.sol";
import {AssetType} from "../../../src/utils/AssetWrapper.sol";

/**
 * @title AssetCurveBuilder
 * Utility functions helpful for building an asset release intent curve.
 */
library AssetCurveBuilder {
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
}
