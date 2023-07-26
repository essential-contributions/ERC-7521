// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/standards/assetbased/AssetBasedIntentData.sol";
import "./TestEnvironment.sol";

contract AssetBasedIntentDataTest is Test, TestEnvironment {
    using AssetBasedIntentDataLib for AssetBasedIntentData;

    function test_validate() public pure {
        _data().validate();
    }

    function test_validate_invalidAssets() public {
        AssetBasedIntentData memory data = _data();
        data.assetReleases[0].params = new int256[](0);
        vm.expectRevert("invalid curve params");
        data.validate();
    }
}
