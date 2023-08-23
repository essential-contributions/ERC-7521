// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/standards/assetbased/AssetBasedIntentData.sol";
import "./utils/TestEnvironment.sol";

contract AssetBasedIntentDataTest is TestEnvironment {

    function test_validate() public pure {
        _data().validate();
    }

    function test_validate_invalidAssets() public {
        AssetBasedIntentSegment[] memory segments = _data();
        segments[0].assetReleases[0].params = new int256[](0);
        vm.expectRevert("invalid curve params");
        data.validate();
    }

    function test_validate_relativeRequirementAtBeginning() public {
        AssetBasedIntentSegment[] memory intentSegments = new AssetBasedIntentSegment[](2);
        // relative requirement
        AssetBasedIntentCurve memory constantETHCurve =
            _curveETH(AssetBasedIntentCurveBuilder.constantCurve(10), EvaluationType.RELATIVE);

        AssetBasedIntentCurve[] memory assetRequirements = new AssetBasedIntentCurve[](2);
        assetRequirements[0] = constantETHCurve;

        intentSegments[0].assetRequirements = assetRequirements;

        AssetBasedIntentData memory assetBasedIntentData = AssetBasedIntentData({intentSegments: intentSegments});

        vm.expectRevert("relative requirements not allowed at beginning of intent");
        assetBasedIntentData.validate();
    }
}
