// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../../src/interfaces/DeployableIntentStandard.sol";

contract EntryPointTest is TestEnvironment {
    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0x7683e8b0796fa3d4f7a8b48b0ce7e60cd3aac896d6551361a9dd448bc6d4cf1b;
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        assertEq(intentHash, expectedHash);
    }

    function test_registerIntentStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        DeployableEthReleaseLinear newIntentStandard = new DeployableEthReleaseLinear();
        newEntryPoint.registerIntentStandard(newIntentStandard);
        bytes32 registeredStandardId =
            keccak256(abi.encodePacked(newIntentStandard, address(newEntryPoint), block.chainid));
        DeployableIntentStandard registeredStandard = newEntryPoint.getIntentStandardContract(registeredStandardId);
        bytes32 expectedHash = keccak256(abi.encode(DeployableIntentStandard(newIntentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failRegisterIntentStandard_alreadyRegistered() public {
        vm.expectRevert("AA81 already registered");
        _entryPoint.registerIntentStandard(_ethReleaseLinear);
    }

    function test_getIntentStandardContract() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseLinear);
        DeployableIntentStandard registeredStandard = _entryPoint.getIntentStandardContract(standardId);
        bytes32 expectedHash = keccak256(abi.encode(DeployableIntentStandard(_ethReleaseLinear)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentStandardContract_unknownStandard() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseLinear);
        vm.expectRevert("AA82 unknown standard");
        _entryPoint.getIntentStandardContract(standardId << 1);
    }

    function test_getIntentStandardId() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseLinear);
        bytes32 expectedStandardId = _entryPoint.getIntentStandardId(_ethReleaseLinear);
        assertEq(standardId, expectedStandardId);
    }

    function test_failGetIntentStandardId_unknownStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        DeployableEthReleaseLinear newIntentStandard = new DeployableEthReleaseLinear();
        vm.expectRevert("AA82 unknown standard");
        newEntryPoint.getIntentStandardId(newIntentStandard);
    }
}
