// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/ScenarioTestEnvironment.sol";

// TODO: resolve error message mismatch issue and distribute tests to scenarios

contract AbstractAccountTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    uint256 internal constant _WRONG_PRIVATE_KEY = uint256(keccak256("wrong_account_private_key"));
    address internal _wrongPublicAddress = _getPublicAddress(_WRONG_PRIVATE_KEY);

    function test_entryPoint() public {
        assertEq(address(_account.entryPoint()), address(_entryPoint));
    }

    // function test_executeMulti_invalidInputs() public {
    //     // targets.length != values.length
    //     address[] memory targets = new address[](2);
    //     uint256[] memory values = new uint256[](1);
    //     bytes[] memory datas = new bytes[](2);

    //     AssetBasedIntentSegment memory intentSegment = AssetBasedIntentSegmentBuilder.create(
    //         abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
    //     );

    //     UserIntent memory intent = _intent();
    //     intent = intent.addSegment(intentSegment);
    //     intent = _signIntent(intent);

    //     IEntryPoint.IntentSolution memory solution = _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

    //     // TODO: investigate why the caught revert is slightly different
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
    //         )
    //     );
    //     _entryPoint.handleIntents(solution);
    // }

    // function test_executeMulti_invalidInputs2() public {
    //     // targets.length != datas.length
    //     address[] memory targets = new address[](2);
    //     uint256[] memory values = new uint256[](2);
    //     bytes[] memory datas = new bytes[](1);

    //     AssetBasedIntentSegment memory intentSegment = AssetBasedIntentSegmentBuilder.create(
    //         abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
    //     );

    //     UserIntent memory intent = _intent();
    //     intent = intent.addSegment(intentSegment);
    //     intent = _signIntent(intent);

    //     IEntryPoint.IntentSolution memory solution = _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

    //     // TODO: investigate why the caught revert is slightly different
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
    //         )
    //     );
    //     _entryPoint.handleIntents(solution);
    // }

    // function test_releaseAsset_insufficientBalance() public {
    //     UserIntent memory intent = _intent();
    //     // account has 100 ether but is trying to release 200 ether
    //     intent = intent.addSegment(
    //         _segment("").releaseERC20(address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(200 ether))
    //     );
    //     intent = intent.addSegment(
    //         _segment("").requireETH(
    //             AssetBasedIntentCurveBuilder.linearCurve((3 ether) / 3000, 7 ether, 3000, true), true
    //         )
    //     );
    //     intent = _signIntent(intent);

    //     bytes[] memory steps1 =
    //         _solverSwapAllERC20ForETHAndForward(10 ether, address(_publicAddressSolver), 9 ether, address(_account));
    //     bytes[] memory steps2;
    //     IEntryPoint.IntentSolution memory solution = _solution(_singleIntent(intent), steps1, steps2, _noSteps());

    //     // TODO: investigate why the caught revert is slightly different
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: insufficient release balance"
    //         )
    //     );
    //     _entryPoint.handleIntents(solution);
    // }

    function test_validateSignature() public {
        AbstractAccount wrongAbstractAccount = new AbstractAccount(_entryPoint, _intentStandard, _wrongPublicAddress);
        _testERC20.mint(address(wrongAbstractAccount), 100 ether);
        vm.deal(address(wrongAbstractAccount), 100 ether);
        vm.warp(1000);

        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment("").releaseERC20(address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(2 ether))
        );
        intent = intent.addSegment(
            _segment("").requireETH(
                AssetBasedIntentCurveBuilder.linearCurve((3 ether) / 3000, 7 ether, 3000, true), true
            )
        );
        intent = _signIntent(intent);

        // sigFailed == false for passing validation
        uint256 validationData = _packValidationData(false, uint48(intent.timestamp), 0);
        ValidationData memory valData = _parseValidationData(validationData);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.ValidationResult.selector, valData.sigFailed, valData.validAfter, valData.validUntil
            )
        );
        _entryPoint.simulateValidation(intent);
    }

    function test_validateSignature_wrongSignature() public {
        AbstractAccount wrongAbstractAccount = new AbstractAccount(_entryPoint, _intentStandard, _wrongPublicAddress);
        _testERC20.mint(address(wrongAbstractAccount), 100 ether);
        vm.deal(address(wrongAbstractAccount), 100 ether);
        vm.warp(1000);

        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment("").releaseERC20(address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(2 ether))
        );
        intent = intent.addSegment(
            _segment("").requireETH(
                AssetBasedIntentCurveBuilder.linearCurve((3 ether) / 3000, 7 ether, 3000, true), true
            )
        );

        bytes32 intentHash = intent.hash();
        bytes32 digest = intentHash.toEthSignedMessageHash();
        // sign intent with wrong private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_WRONG_PRIVATE_KEY, digest);
        intent.signature = abi.encodePacked(r, s, v);

        // sigFailed == true for failing validation
        uint256 validationData = _packValidationData(true, uint48(intent.timestamp), 0);
        ValidationData memory valData = _parseValidationData(validationData);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.ValidationResult.selector, valData.sigFailed, valData.validAfter, valData.validUntil
            )
        );
        _entryPoint.simulateValidation(intent);
    }
}
