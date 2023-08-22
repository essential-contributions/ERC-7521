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

    function test_failAddTrustedIntentStandard_notOwner() public {
        uint256 _testPrivateKey = uint256(keccak256("test_account_private_key"));
        address _testPublicAddress = _getPublicAddress(_testPrivateKey);

        AbstractAccount _newAccount = new AbstractAccount(_entryPoint, _testPublicAddress);

        // do not prank as owner

        vm.expectRevert("standard must be trusted by owner");
        _newAccount.addTrustedIntentStandard(_assetBasedIntentStandard);
    }

    function test_failAddTrustedIntentStandard_notRegistered() public {
        EntryPoint _newEntryPoint = new EntryPoint();
        // new standard uses a different entry point than the one that account trusts
        AssetBasedIntentStandard _assetBasedIntentStandard = new AssetBasedIntentStandard(_newEntryPoint);

        // prank as owner and attempt to add intent standard to account's trusted standards
        vm.prank(_account.owner());
        vm.expectRevert("AA83 unknown standard");
        _account.addTrustedIntentStandard(_assetBasedIntentStandard);
    }
}
