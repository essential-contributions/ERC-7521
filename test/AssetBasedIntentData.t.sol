// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/interfaces/UserIntent.sol";
import "../src/standards/AssetBasedIntentData.sol";
import "./TestUtil.sol";

contract AssetBasedIntentDataTest is Test, TestUtil {
    using AssetBasedIntentDataLib for AssetBasedIntentData;
    using UserIntentLib for UserIntent;

    function test_validate() public view {
        assetBasedIntentDataMap[0].validate();
    }

    function test_validate_invalidAssets() public {
        AssetBasedIntentData memory assetBasedIntentData = assetBasedIntentDataMap[0];
        assetBasedIntentData.assetReleases[0].params = new uint256[](0);
        vm.expectRevert("invalid curve params");
        assetBasedIntentData.validate();
    }

    function test_parseAssetBasedIntentData() public {
        // TODO
    }
}
