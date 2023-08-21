// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";
import {_packValidationData} from "../../src/utils/Helpers.sol";
import "../../src/test/TestAbstractAccount.sol";

contract HandleIntentsTest is ScenarioTestEnvironment {
    function test_failHandleIntents_noIntents() public {
        UserIntent[] memory noIntents = new UserIntent[](0);
        IEntryPoint.IntentSolution memory solution = _solution(noIntents, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert("AA70 no intents");
        _entryPoint.handleIntents(solution);

        vm.expectRevert("AA70 no intents");
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_failHandleIntents_mismatchedStandards() public {
        // intent with a different standard id
        UserIntent memory intentWithDifferentStandard =
            AssetBasedIntentBuilder.create(_intentStandard.standardId() << 1, address(_account), 0, 0);

        UserIntent[] memory intents = new UserIntent[](2);
        intents[0] = _intent();
        intents[1] = intentWithDifferentStandard;

        IEntryPoint.IntentSolution memory solution = _solution(intents, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert("AA71 mismatched intent standards");
        _entryPoint.handleIntents(solution);

        vm.expectRevert("AA71 mismatched intent standards");
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_failHandleIntents_invalidTimestamp() public {
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(_intent()), _noSteps(), _noSteps(), _noSteps());
        // TIMESTAMP_MAX_OVER of EntryPoint.sol is 6
        solution.timestamp = block.timestamp + 7;

        vm.expectRevert("AA81 invalid timestamp");
        _entryPoint.handleIntents(solution);

        vm.expectRevert("AA81 invalid timestamp");
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }
}

contract ValidateUserIntentTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function test_fail_unknownStandard() public {
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(_intent()), _noSteps(), _noSteps(), _noSteps());

        EntryPoint newEntryPoint = new EntryPoint();

        // call handleIntents from a different entry point
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA83 unknown standard"));
        newEntryPoint.handleIntents(solution);

        // call simulateHandleIntents from a different entry point
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA83 unknown standard"));
        newEntryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_validateWithStandard() public {
        UserIntent memory intent = _intent();
        AssetBasedIntentSegment memory segment = _segment("").releaseETH(AssetBasedIntentCurveBuilder.constantCurve(10));
        // invalidate curve params
        segment.assetReleases[0].params = new int256[](0);
        intent = intent.addSegment(segment);
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA62 reverted: invalid curve params")
        );
        _entryPoint.handleIntents(solution);

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA62 reverted: invalid curve params")
        );
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_validateWithAccount() public {
        UserIntent memory intent = _intent();

        // do not sign intent

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA23 reverted: ECDSA: invalid signature length"
            )
        );
        _entryPoint.handleIntents(solution);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA23 reverted: ECDSA: invalid signature length"
            )
        );
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_invalidNonce() public {
        // use wrong nonce while creating intent
        UserIntent memory intent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 123, 0);
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA25 invalid account nonce"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA25 invalid account nonce"));
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }
}

contract ValidateAccountValidationDataTest is ScenarioTestEnvironment {
    using ECDSA for bytes32;

    function test_fail_signatureError() public {
        UserIntent memory intent = _intent();
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        // sign with wrong private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(12345, digest);
        intent.signature = abi.encodePacked(r, s, v);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA24 signature error"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA24 signature error"));
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_expired() public {
        UserIntent memory intent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 0, block.timestamp);
        intent = _signIntent(intent);

        vm.warp(block.timestamp + 1);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_notDue() public {
        uint256 _testPrivateKey = uint256(keccak256("test_account_private_key"));
        address _testPublicAddress = _getPublicAddress(_testPrivateKey);

        TestAbstractAccount _testAccount = new TestAbstractAccount(_entryPoint, _intentStandard, _testPublicAddress);

        UserIntent memory intent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_testAccount), 0, 0);
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_testPrivateKey, digest);
        intent.signature = abi.encodePacked(r, s, v);

        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }
}

contract HandleMultiSolutionIntentsTest is ScenarioTestEnvironment {
// TODO
}
