// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";
import {TestAbstractAccount} from "../../../src/test/TestAbstractAccount.sol";

contract HandleIntentsTest is ScenarioTestEnvironment {
    function test_failHandleIntents_noIntents() public {
        IntentSolution memory solution = _emptySolution();

        vm.expectRevert("AA70 no intents");
        _entryPoint.handleIntents(solution);

        vm.expectRevert("AA70 no intents");
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_failHandleIntents_invalidTimestamp() public {
        IntentSolution memory solution = _solution(_intent(), _intent());
        // TIMESTAMP_MAX_OVER of EntryPoint.sol is 6
        solution.timestamp = block.timestamp + 7;

        vm.expectRevert("AA71 invalid timestamp");
        _entryPoint.handleIntents(solution);

        vm.expectRevert("AA72 simulation requires timestamp");
        solution.timestamp = 0;
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }
}

contract ValidateUserIntentTest is ScenarioTestEnvironment {
    using EthReleaseIntentSegmentBuilder for EthReleaseIntentSegment;

    function test_fail_standardAndDataLengthMismatch() public {
        UserIntent memory intent = _intent();

        // intent standards.length == intentData.length + 1
        bytes32[] memory standards = new bytes32[](1);
        standards[0] = _ethReleaseIntentStandard.standardId();
        intent.standards = standards;

        IntentSolution memory solution = _solution(intent, _intent());

        // call handleIntents with mismatched standard and data length
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA83 standards.length != intentData.length"
            )
        );
        _entryPoint.handleIntents(solution);

        // call simulateHandleIntents with mismatched standard and data length
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA83 standards.length != intentData.length"
            )
        );
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_fail_unknownStandard() public {
        UserIntent memory intent = _intent();
        intent = _addCallSegment(intent, CallIntentSegmentBuilder.create(""));
        // invalidate standard id
        intent.standards[0] = bytes32(uint256(123));

        IntentSolution memory solution = _solution(intent, _intent());

        // call handleIntents with an unknown intent standard
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA82 unknown standard"));
        _entryPoint.handleIntents(solution);

        // call simulateHandleIntents with an unknown intent standard
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA82 unknown standard"));
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_fail_validateWithStandard() public {
        UserIntent memory intent = _intent();
        EthReleaseIntentSegment memory segment =
            EthReleaseIntentSegmentBuilder.create().releaseETH(CurveBuilder.constantCurve(10));
        // invalidate curve params
        segment.release.params = new int256[](0);
        intent = _addEthReleaseSegment(intent, segment);
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _intent());

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA62 reverted: invalid curve params")
        );
        _entryPoint.handleIntents(solution);

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA62 reverted: invalid curve params")
        );
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_fail_validateWithAccount() public {
        UserIntent memory intent = _intent();

        // do not sign intent

        IntentSolution memory solution = _solution(intent, _intent());

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
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_fail_invalidNonce() public {
        // use wrong nonce while creating intent
        UserIntent memory intent = IntentBuilder.create(address(_account), 123, 0);
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _intent());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA25 invalid account nonce"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA25 invalid account nonce"));
        _entryPoint.simulateHandleIntents(solution, address(0), "");
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

        IntentSolution memory solution = _solution(intent, _intent());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA24 signature error"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA24 signature error"));
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_fail_expired() public {
        UserIntent memory intent = IntentBuilder.create(address(_account), 0, block.timestamp);
        intent = _signIntent(intent);

        vm.warp(block.timestamp + 1);

        IntentSolution memory solution = _solution(intent, _intent());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }

    function test_fail_notDue() public {
        uint256 _testPrivateKey = uint256(keccak256("test_account_private_key"));
        address _testPublicAddress = _getPublicAddress(_testPrivateKey);

        TestAbstractAccount _testAccount = new TestAbstractAccount(_entryPoint, _testPublicAddress);

        UserIntent memory intent = IntentBuilder.create(address(_testAccount), 0, 0);
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_testPrivateKey, digest);
        intent.signature = abi.encodePacked(r, s, v);

        IntentSolution memory solution = _solution(intent, _intent());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.handleIntents(solution);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.simulateHandleIntents(solution, address(0), "");
    }
}

contract HandleMultiSolutionIntentsTest is ScenarioTestEnvironment {
// TODO
}
