// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetCurve, AssetType, AssetCurveLib} from "./AssetCurve.sol";
import {AssetType} from "../interfaces/IAssetRelease.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * Utility functions helpful when working with AssetCurve structs and asset interactions.
 */
library AssetWrapper {
    using AssetCurveLib for AssetCurve;

    function balanceOf(AssetCurve memory curve, address owner) public view returns (uint256) {
        if(curve.assetType == AssetType.ETH) {
            return owner.balance;

        } else if(curve.assetType == AssetType.ERC20) {
            return IERC20(curve.assetContract).balanceOf(owner);

        } else if(curve.assetType == AssetType.ERC721) {
            //TODO

        } else if(curve.assetType == AssetType.ERC777) {
            //TODO

        } else if(curve.assetType == AssetType.ERC1155) {
            //TODO

        }
        return 0;
    }


}
