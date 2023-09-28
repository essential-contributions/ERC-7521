// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../interfaces/UserIntent.sol";
import {AssetBasedIntentCurve} from "./AssetBasedIntentCurve.sol";

/**
 * Asset Based Intent Segment struct
 * @param callGasLimit max gas to be spent on the intent call data.
 * @param callData the intents desired call data.
 * @param assetRelease list of assets that are released before the solution gets executed.
 * @param assetRequirements list of assets that are required to be owned by the account at the end of the solution execution.
 */
struct AssetBasedIntentSegment {
    uint256 callGasLimit;
    bytes callData;
    AssetBasedIntentCurve[] assetReleases;
    AssetBasedIntentCurve[] assetRequirements;
}

/**
 * Helper function to extract AssetBasedIntentSegment from a UserIntent.
 */
function parseAssetBasedIntentSegment(UserIntent calldata intent, uint256 index)
    pure
    returns (AssetBasedIntentSegment calldata segment)
{
    bytes calldata intentData = intent.intentData[index];
    assembly {
        segment := intentData.offset
    }
}
