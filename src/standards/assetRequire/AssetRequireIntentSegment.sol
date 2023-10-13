// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetCurve} from "../../utils/AssetCurve.sol";

/**
 * Asset Require Intent Segment struct
 * @param assetRequirement asset that is required to be owned by the account at the end of the solution execution.
 */
struct AssetRequireIntentSegment {
    AssetCurve assetRequirement;
}
