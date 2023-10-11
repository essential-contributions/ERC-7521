// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetBasedIntentCurve} from "./AssetBasedIntentCurve.sol";

/**
 * Asset Based Intent Segment struct
 * @param callData the intents desired call data.
 * @param assetRelease list of assets that are released before the solution gets executed.
 * @param assetRequirements list of assets that are required to be owned by the account at the end of the solution execution.
 */
struct AssetBasedIntentSegment {
    bytes callData;
    AssetBasedIntentCurve[] assetReleases;
    AssetBasedIntentCurve[] assetRequirements;
}
