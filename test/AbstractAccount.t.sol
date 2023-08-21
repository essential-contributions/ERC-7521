// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/ScenarioTestEnvironment.sol";

contract AbstractAccountTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    function test_entryPoint() public {
        assertEq(address(_account.entryPoint()), address(_entryPoint));
    }

    function test_executeMulti_invalidInputs() public {
        // targets.length != values.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](2);

        AssetBasedIntentSegment memory intentSegment = AssetBasedIntentSegmentBuilder.create(
            abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
        );

        UserIntent memory intent = _intent();
        intent = intent.addSegment(intentSegment);
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_executeMulti_invalidInputs2() public {
        // targets.length != datas.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](1);

        AssetBasedIntentSegment memory intentSegment = AssetBasedIntentSegmentBuilder.create(
            abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
        );

        UserIntent memory intent = _intent();
        intent = intent.addSegment(intentSegment);
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failCall() public {
        UserIntent memory intent = _intent();
        // account is not funded, the call will fail
        intent = intent.addSegment(_segment(_accountBuyERC1155(_testERC1155.nftCost())));
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }
}
