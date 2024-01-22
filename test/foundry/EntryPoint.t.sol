// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../../src/interfaces/IIntentStandard.sol";
import "../../src/interfaces/IEntryPoint.sol";

contract EntryPointTest is TestEnvironment {
    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0xd684a3f0f9155e9f51b03e1d2f70b40bef641d0a5805c61afcb858bac972e8a6;
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        assertEq(intentHash, expectedHash);
    }

    function test_registerIntentStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        EthRelease newIntentStandard = new EthRelease();
        newEntryPoint.registerIntentStandard(newIntentStandard);
        bytes32 registeredStandardId =
            keccak256(abi.encodePacked(newIntentStandard, address(newEntryPoint), block.chainid));
        IIntentStandard registeredStandard = newEntryPoint.getIntentStandardContract(registeredStandardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(newIntentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_getUserNonce() public {
        UserIntent memory intent = _intent();
        uint256 userNonce = _entryPoint.getNonce(intent.sender, uint256(0));
        assertEq(userNonce, 0);
    }

    function test_validateIntent() public view {
        UserIntent memory intent = _intent();
        intent = _addSimpleCall(intent, "");
        intent = _addErc20Record(intent, false);
        intent = _addErc20Release(intent, 1 ether, false);
        intent = _addErc20Require(intent, 1 ether, false, false);
        intent = _addEthRecord(intent, false);
        intent = _addEthRelease(intent, 1 ether);
        intent = _addEthRequire(intent, 1 ether, false, false);
        intent = _addSequentialNonce(intent, 1);
        intent = _addUserOp(intent, 100_000, "");

        //embedded standards
        intent = _signIntent(intent);
        _entryPoint.validateIntent(intent);

        //registered standards
        intent = _useRegisteredStandards(intent);
        intent = _signIntent(intent);
        _entryPoint.validateIntent(intent);
    }

    function test_failValidateIntent_unknownStandard() public {
        UserIntent memory intent = _intent();
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encode(bytes32(0x1122334455667788112233445566778811223344556677881122334455667788));
        intent.intentData = datas;

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA82 unknown standard"));
        _entryPoint.validateIntent(intent);
    }

    function test_failValidateIntent_accountNotDeployed() public {
        UserIntent memory intent = _intent();
        intent.sender = address(0);
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA20 account not deployed"));
        _entryPoint.validateIntent(intent);
    }

    function test_failRegisterIntentStandard_alreadyRegistered() public {
        vm.expectRevert("AA81 already registered");
        _entryPoint.registerIntentStandard(_ethReleaseStandard);
    }

    function test_getIntentStandardContract() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseStandard);
        IIntentStandard registeredStandard = _entryPoint.getIntentStandardContract(standardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(_ethReleaseStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentStandardContract_unknownStandard() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseStandard);
        vm.expectRevert("AA82 unknown standard");
        _entryPoint.getIntentStandardContract(standardId << 1);
    }

    function test_getIntentStandardId() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseStandard);
        bytes32 expectedStandardId = _entryPoint.getIntentStandardId(_ethReleaseStandard);
        assertEq(standardId, expectedStandardId);
    }

    function test_failGetIntentStandardId_unknownStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        EthRelease newIntentStandard = new EthRelease();
        vm.expectRevert("AA82 unknown standard");
        newEntryPoint.getIntentStandardId(newIntentStandard);
    }

    function test_failHandleIntents_tooManySegments() public {
        UserIntent memory intent = _intent();
        for (uint256 i = 0; i < 256 + 1; i++) {
            intent = _addSequentialNonce(intent, i + 1);
        }
        intent = _signIntent(intent);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA63 too many segments"));
        _entryPoint.handleIntents(_solution(intent));
    }

    function test_failHandleIntents_notFullyExecuted() public {
        UserIntent memory intent = _intent();
        for (uint256 i = 0; i < 4; i++) {
            intent = _addSequentialNonce(intent, i + 1);
        }
        intent = _signIntent(intent);
        IntentSolution memory solution = _solution(intent);
        solution.order = new uint256[](3);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 3, "AA69 not fully executed"));
        _entryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_unknownStandard() public {
        UserIntent memory intent = _intent();
        bytes[] memory datas = new bytes[](1);
        datas[0] = abi.encode(bytes32(0x1122334455667788112233445566778811223344556677881122334455667788));
        intent.intentData = datas;
        intent = _signIntent(intent);
        IntentSolution memory solution = _solution(intent);

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA82 unknown standard"));
        _entryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_invalidExecutionContext() public {
        UserIntent memory intent = _intent();
        intent = _addFailingStandard(intent, false, true);
        intent = _signIntent(intent);
        IntentSolution memory solution = _solution(intent);

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA60 invalid execution context")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_intentStandardFailure() public {
        UserIntent memory intent = _intent();
        intent = _addFailingStandard(intent, false, false);
        intent = _signIntent(intent);
        IntentSolution memory solution = _solution(intent);

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failHandleIntent_intentStandardFailureWithReason() public {
        UserIntent memory intent = _intent();
        intent = _addFailingStandard(intent, true, false);
        intent = _signIntent(intent);
        IntentSolution memory solution = _solution(intent);

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: test revert")
        );
        _entryPoint.handleIntents(solution);
    }
}
