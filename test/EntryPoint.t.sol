// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../contracts/interfaces/IIntentStandard.sol";

contract EntryPointTest is TestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0xe22be1eb6103dde4c858bc47812dbedc31b6dee395fb40280782df84606c7fdf;
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        assertEq(intentHash, expectedHash);
    }

    function test_registerIntentStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentStandard newIntentStandard = new AssetBasedIntentStandard(newEntryPoint);
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
        AssetBasedIntentStandard newIntentStandard = new AssetBasedIntentStandard(newEntryPoint);
        vm.expectRevert("AA80 invalid standard");
        _entryPoint.registerIntentStandard(newIntentStandard);
    }

    function test_failRegisterIntentStandard_alreadyRegistered() public {
        vm.expectRevert("AA81 already registered");
        _entryPoint.registerIntentStandard(_assetBasedIntentStandard);
    }

    function test_getIntentStandardContract() public {
        bytes32 standardId = _assetBasedIntentStandard.standardId();
        IIntentStandard registeredStandard = _entryPoint.getIntentStandardContract(standardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(_assetBasedIntentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentStandardContract_unknownStandard() public {
        bytes32 standardId = _assetBasedIntentStandard.standardId();
        vm.expectRevert("AA82 unknown standard");
        _entryPoint.getIntentStandardContract(standardId << 1);
    }

    function test_getIntentStandardId() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_assetBasedIntentStandard);
        bytes32 expectedStandardId = _assetBasedIntentStandard.standardId();
        assertEq(standardId, expectedStandardId);
    }

    function test_failGetIntentStandardId_unknownStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentStandard newIntentStandard = new AssetBasedIntentStandard(newEntryPoint);
        vm.expectRevert("AA82 unknown standard");
        newEntryPoint.getIntentStandardId(newIntentStandard);
    }
}
