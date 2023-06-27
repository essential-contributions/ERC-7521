// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

enum AssetType {
    ETH,
    ERC20,
    ERC721,
    ERC721_ID,
    ERC777,
    ERC1155,
    COUNT
}

interface IAssetRelease {
    /**
     * Release the given token(s) (both fungible and non-fungible)
     *
     * @dev Must validate caller is the entryPoint.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param amount the amount to release.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, uint256 amount) external;
}
