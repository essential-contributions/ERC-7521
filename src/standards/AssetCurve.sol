// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * Asset Curve struct
 * @param assetId the ID of the asset.
 * @param assetType the type of the asset (ETH, ERC-20, ERC-721, etc).
 * @param curveType the curve type (constant, linear, exponential).
 * @param params the parameters for the curve.
 */
struct AssetCurve {
    uint256 assetId;
    uint256 assetType;
    uint256 curveType;
    uint256[] params;
}

/**
 * Utility functions helpful when working with AssetCurve structs.
 */
library AssetCurveLib {
    function pack(AssetCurve memory curve) public pure returns (bytes memory ret) {
        return abi.encode(curve);
    }

    function hash(AssetCurve memory curve) public pure returns (bytes32) {
        return keccak256(pack(curve));
    }

    function hash(AssetCurve[] memory curves) public pure returns (bytes32) {
        return keccak256(abi.encode(curves));
    }

    //TODO: function to check is intent asset based
}
