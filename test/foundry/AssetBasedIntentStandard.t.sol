// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";

contract AssetBasedIntentStandardTest is TestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;

    function _dataForAssetRequirementCheck(EvaluationType evaluationType)
        internal
        pure
        returns (AssetBasedIntentSegment[] memory)
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

        return intentSegments;
    }

    function test_entryPoint() public {
        assertEq(address(_assetBasedIntentStandard.entryPoint()), address(_entryPoint));
    }

    function test_validate() public view {
        UserIntent memory intent = _intent();
        for (uint256 i = 0; i < intent.intentData.length; i++) {
            _assetBasedIntentStandard.validateIntentSegment(intent.intentData[i]);
        }
    }

    function test_validate_multipleAssetRequirement() public view {
        UserIntent memory intent = _intent();
        AssetBasedIntentSegment[] memory segments = _dataForAssetRequirementCheck(EvaluationType.ABSOLUTE);
        intent = intent.encodeData(segments[0]);
        intent = intent.encodeData(segments[1]);

        for (uint256 i = 0; i < intent.intentData.length; i++) {
            _assetBasedIntentStandard.validateIntentSegment(intent.intentData[i]);
        }
    }
}
