// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../../src/interfaces/IIntentStandard.sol";

contract EntryPointTest is TestEnvironment {
    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0x0657772e5d310553fa34314f6b3fc1a0d3935aec895150d8be0a8f8ad08bd8dd;
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

    function test_failRegisterIntentStandard_alreadyRegistered() public {
        vm.expectRevert("AA81 already registered");
        _entryPoint.registerIntentStandard(_ethRelease);
    }

    function test_getIntentStandardContract() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethRelease);
        IIntentStandard registeredStandard = _entryPoint.getIntentStandardContract(standardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(_ethRelease)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentStandardContract_unknownStandard() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethRelease);
        vm.expectRevert("AA82 unknown standard");
        _entryPoint.getIntentStandardContract(standardId << 1);
    }

    function test_getIntentStandardId() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethRelease);
        bytes32 expectedStandardId = _entryPoint.getIntentStandardId(_ethRelease);
        assertEq(standardId, expectedStandardId);
    }

    function test_failGetIntentStandardId_unknownStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        EthRelease newIntentStandard = new EthRelease();
        vm.expectRevert("AA82 unknown standard");
        newEntryPoint.getIntentStandardId(newIntentStandard);
    }
}
