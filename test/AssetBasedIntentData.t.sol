// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";

contract AssetBasedIntentDataTest is TestEnvironment {
    using AssetBasedIntentDataLib for AssetBasedIntentData;

    function _dataForAssetRequirementCheck(EvaluationType evaluationType)
        internal
        pure
        returns (AssetBasedIntentData memory)
    {
        AssetBasedIntentSegment[] memory intentSegments = new AssetBasedIntentSegment[](2);

        AssetBasedIntentCurve memory constantETHCurve =
            _curveETH(AssetBasedIntentCurveBuilder.constantCurve(10), evaluationType);

        AssetBasedIntentCurve[] memory assetRequirements = new AssetBasedIntentCurve[](1);
        assetRequirements[0] = constantETHCurve;

        AssetBasedIntentCurve[] memory assetReleases = new AssetBasedIntentCurve[](1);
        assetReleases[0] = constantETHCurve;

        intentSegments[0].assetRequirements = assetRequirements;
        intentSegments[1].assetReleases = assetReleases;

        return AssetBasedIntentData({intentSegments: intentSegments});
    }

    function test_validate() public pure {
        _data().validate();
    }

    function test_validate_multipleAssetRequirement() public pure {
        AssetBasedIntentData memory assetBasedIntentData = _dataForAssetRequirementCheck(EvaluationType.ABSOLUTE);
        assetBasedIntentData.validate();
    }

    function test_validate_invalidAssets() public {
        AssetBasedIntentData memory data = _data();
        data.intentSegments[0].assetReleases[0].params = new int256[](0);
        vm.expectRevert("invalid curve params");
        data.validate();
    }

    function test_validate_relativeRequirementAtBeginning() public {
        // relative requirement
        AssetBasedIntentData memory assetBasedIntentData = _dataForAssetRequirementCheck(EvaluationType.RELATIVE);

        vm.expectRevert("relative requirements not allowed at beginning of intent");
        assetBasedIntentData.validate();
    }
}
