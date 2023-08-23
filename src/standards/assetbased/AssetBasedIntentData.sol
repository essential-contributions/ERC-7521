// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetBasedIntentCurve, AssetBasedIntentCurveLib} from "./AssetBasedIntentCurve.sol";
import {UserIntent} from "../../interfaces/UserIntent.sol";

/**
 * Asset Based Intent Data struct
 * @param intentSegments list of different segments in an asset based intent.
 */
struct AssetBasedIntentData {
    AssetBasedIntentSegment[] intentSegments;
}

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
 * Utility functions helpful when working with AssetBasedIntentData structs.
 */
library AssetBasedIntentDataLib {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    function validate(AssetBasedIntentData calldata data) public pure {
        // check over the first segment first
        if (data.intentSegments.length > 0) {
            for (uint256 i = 0; i < data.intentSegments[0].assetRequirements.length; i++) {
                require(
                    !data.intentSegments[0].assetRequirements[i].isRelativeEvaluation(),
                    "relative requirements not allowed at beginning of intent"
                );
                data.intentSegments[0].assetRequirements[i].validate();
            }
            for (uint256 i = 0; i < data.intentSegments[0].assetReleases.length; i++) {
                data.intentSegments[0].assetReleases[i].validate();
            }
        }

        // check through remaining segments
        for (uint256 j = 1; j < data.intentSegments.length; j++) {
            for (uint256 i = 0; i < data.intentSegments[j].assetRequirements.length; i++) {
                data.intentSegments[j].assetRequirements[i].validate();
            }
            for (uint256 i = 0; i < data.intentSegments[j].assetReleases.length; i++) {
                data.intentSegments[j].assetReleases[i].validate();
            }
        }
    }
}

/**
 * Helper function to extract AssetBasedIntentData from a UserIntent.
 */
function parseAssetBasedIntentData(UserIntent calldata intent) pure returns (AssetBasedIntentData calldata data) {
    bytes calldata intentData = intent.intentData;
    assembly {
        data := intentData.offset
    }
}
