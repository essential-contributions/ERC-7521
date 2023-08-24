// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetBasedIntentCurve, AssetBasedIntentCurveLib} from "./AssetBasedIntentCurve.sol";
import {AssetType} from "./utils/AssetWrapper.sol";

interface IAssetRelease {
    /**
     * Release the given token(s) (both fungible and non-fungible)
     *
     * @dev Must validate caller is the entryPoint and that it is currently processing intents.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param to the target to release tokens to.
     * @param amount the amount to release.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external;
}

function encodeReleaseAsset(AssetBasedIntentCurve memory assetRelease, address to, uint256 amount)
    pure
    returns (bytes memory)
{
    return abi.encodeWithSelector(
        IAssetRelease.releaseAsset.selector,
        AssetBasedIntentCurveLib.assetType(assetRelease),
        assetRelease.assetContract,
        assetRelease.assetId,
        to,
        amount
    );
}
