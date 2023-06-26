// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./UserIntent.sol";

interface IAssetRelease {
    function releaseAsset(uint256 assetType, uint256 assetId, uint256 amount) external;
}
