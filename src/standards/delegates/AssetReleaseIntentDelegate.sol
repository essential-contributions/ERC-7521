// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetCurve, parseAssetType} from "../../utils/curves/AssetCurve.sol";
import {AssetType, _balanceOf, _transfer} from "../../utils/wrappers/AssetWrapper.sol";

contract AssetReleaseIntentDelegate {
    /**
     * Basic state and constants.
     */
    address private immutable _this;

    /**
     * Contract constructor.
     */
    constructor() {
        _this = address(this);
    }

    /**
     * Release the given token(s) (both fungible and non-fungible)
     * @dev only allowed to be called via a delegate call
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param to the target to release tokens to.
     * @param amount the amount to release.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external
    {
        require(address(this) != _this, "must be delegate call");
        require(_balanceOf(assetType, assetContract, assetId, address(this)) >= amount, "insufficient release balance");
        _transfer(assetType, assetContract, assetId, address(this), to, amount);
    }

    function _encodeReleaseAsset(AssetCurve calldata assetRelease, address to, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            this.releaseAsset.selector,
            parseAssetType(assetRelease),
            assetRelease.assetContract,
            assetRelease.assetId,
            to,
            amount
        );
    }
}
