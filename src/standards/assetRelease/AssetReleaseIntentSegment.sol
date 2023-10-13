// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetCurve} from "../../utils/AssetCurve.sol";

/**
 * Asset Release Intent Segment struct
 * @param assetRelease asset to release.
 */
struct AssetReleaseIntentSegment {
    AssetCurve assetRelease;
}
