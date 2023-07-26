// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

contract EntryPointTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;

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

    function test_handleIntent_invalidNonce() public {
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

    function test_handleIntent_targetNonZero() public {
        UserIntent memory userIntent = _createIntent("", "");
        userIntent = _signIntent(userIntent);

        IEntryPoint.SolutionStep[] memory steps1;
        IEntryPoint.SolutionStep[] memory steps2;
        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        vm.expectRevert(abi.encodeWithSignature("ExecutionResult(bool,bool,bytes)", true, false, ""));
        _entryPoint.simulateHandleIntents(solution, 1000, address(this), "");
    }

    function test_registerIntentStandard_duplicate() public {
        vm.expectRevert("AA80 already registered");
        _entryPoint.registerIntentStandard(_intentStandard);
    }
}
