// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../../src/interfaces/IIntentStandard.sol";

contract EntryPointTest is TestEnvironment {
    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0xef1591599af72d67e017ca35ea5134976a0119473ff388f4eccc80742d3da626;
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        assertEq(intentHash, expectedHash);
    }

    function test_registerIntentStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        EthReleaseIntentStandard newIntentStandard = new EthReleaseIntentStandard(newEntryPoint);
        newEntryPoint.registerIntentStandard(newIntentStandard);
        bytes32 registeredStandardId =
            keccak256(abi.encodePacked(newIntentStandard, address(newEntryPoint), block.chainid));
        IIntentStandard registeredStandard = newEntryPoint.getIntentStandardContract(registeredStandardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(newIntentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failRegisterIntentStandard_invalidStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        EthReleaseIntentStandard newIntentStandard = new EthReleaseIntentStandard(newEntryPoint);
        vm.expectRevert("AA80 invalid standard");
        _entryPoint.registerIntentStandard(newIntentStandard);
    }

    function test_failRegisterIntentStandard_alreadyRegistered() public {
        vm.expectRevert("AA81 already registered");
        _entryPoint.registerIntentStandard(_ethReleaseIntentStandard);
    }

    function test_getIntentStandardContract() public {
        bytes32 standardId = _ethReleaseIntentStandard.standardId();
        IIntentStandard registeredStandard = _entryPoint.getIntentStandardContract(standardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(_ethReleaseIntentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentStandardContract_unknownStandard() public {
        bytes32 standardId = _ethReleaseIntentStandard.standardId();
        vm.expectRevert("AA82 unknown standard");
        _entryPoint.getIntentStandardContract(standardId << 1);
    }

    function test_getIntentStandardId() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseIntentStandard);
        bytes32 expectedStandardId = _ethReleaseIntentStandard.standardId();
        assertEq(standardId, expectedStandardId);
    }

    function test_failGetIntentStandardId_unknownStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        EthReleaseIntentStandard newIntentStandard = new EthReleaseIntentStandard(newEntryPoint);
        vm.expectRevert("AA82 unknown standard");
        newEntryPoint.getIntentStandardId(newIntentStandard);
    }
}
