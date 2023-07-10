// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//TODO: is callGasLimit1 and callGasLimit2 necessary?

import {UserIntent} from "../interfaces/UserIntent.sol";
import {AssetBasedIntentCurve, AssetBasedIntentCurveLib} from "./AssetBasedIntentCurve.sol";

/**
 * Asset Based Intent Data struct
 * @param timestamp the time when the intent was created.
 * @param callGasLimit1 max gas to be spent on the first part of intent call data.
 * @param callGasLimit2 max gas to be spent on the second part of intent call data.
 * @param callData1 the first part of the intents desired call data.
 * @param callData2 the second part of the intents desired call data.
 * @param assetRelease list of assets that are released before the solution gets executed.
 * @param assetConstraint list of assets that are required to be owned by the account at the end of the solution execution.
 */
struct AssetBasedIntentData {
    uint256 timestamp;
    uint256 callGasLimit1;
    uint256 callGasLimit2;
    bytes callData1;
    bytes callData2;
    AssetBasedIntentCurve[] assetReleases;
    AssetBasedIntentCurve[] assetConstraints;
}

/**
 * Utility functions helpful when working with AssetBasedIntentData structs.
 */
library AssetBasedIntentDataLib {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    function validate(AssetBasedIntentData calldata data) public pure {
        for (uint256 i = 0; i < data.assetReleases.length; i++) {
            data.assetReleases[i].validate();
        }
        for (uint256 i = 0; i < data.assetConstraints.length; i++) {
            data.assetConstraints[i].validate();
        }
    }
}

/**
 * Helper function to extract AssetBasedIntentData from a USerIntent.
 */
function parseAssetBasedIntentData(UserIntent calldata userInt) pure returns (AssetBasedIntentData calldata data) {
    bytes calldata intentData = userInt.intentData;
    assembly {
        data := intentData.offset
    }
}
