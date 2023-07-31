// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

contract EntryPointTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function test_handleIntent_unknownStandard() public {
        UserIntent memory userIntent = _createIntent("", "");

        IEntryPoint.SolutionStep[] memory steps1;
        IEntryPoint.SolutionStep[] memory steps2;
        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        EntryPoint newEntryPoint = new EntryPoint();

        // call handleIntents from a different entry point
        vm.expectRevert(abi.encodeWithSignature("FailedIntent(uint256,string)", 0, "AA81 unknown standard"));
        newEntryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_validateWithStandard() public {
        UserIntent memory userIntent = _intent();
        AssetBasedIntentSegment memory segment = _segment("").releaseETH(constantCurve(10));
        // invalidate curve params
        segment.assetReleases[0].params = new int256[](0);
        userIntent = userIntent.addSegment(segment);
        userIntent = _signIntent(userIntent);

        IEntryPoint.IntentSolution memory solution = _solution(userIntent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA62 reverted: invalid curve params")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_validateWithAccount() public {
        UserIntent memory userIntent = _intent();

        // do not sign intent

        IEntryPoint.IntentSolution memory solution = _solution(userIntent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA23 reverted: ECDSA: invalid signature length"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_invalidNonce() public {
        // use wrong nonce while creating intent
        UserIntent memory userIntent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 123, 0, "", "");
        userIntent = _signIntent(userIntent);

        IEntryPoint.SolutionStep[] memory steps1;
        IEntryPoint.SolutionStep[] memory steps2;
        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        vm.expectRevert(abi.encodeWithSignature("FailedIntent(uint256,string)", 0, "AA25 invalid account nonce"));
        _entryPoint.handleIntents(solution);
    }
}
