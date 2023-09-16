// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../src/interfaces/IIntentType.sol";

contract EntryPointTest is TestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0xf3fdf47b2366ba3f8ea7e68eb484a561db5cb38606f2905cb7d0f2a58df193bc;
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        assertEq(intentHash, expectedHash);
    }

    function test_registerIntentType() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentType newIntentType = new AssetBasedIntentType(newEntryPoint);
        newEntryPoint.registerIntentType(newIntentType);
        bytes32 registeredTypeId =
            keccak256(abi.encodePacked(newIntentType, address(newEntryPoint), block.chainid));
        IIntentType registeredType = newEntryPoint.getIntentTypeContract(registeredTypeId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentType(newIntentType)));
        bytes32 registeredHash = keccak256(abi.encode(registeredType));
        assertEq(registeredHash, expectedHash);
    }

    function test_failRegisterIntentType_invalidType() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentType newIntentType = new AssetBasedIntentType(newEntryPoint);
        vm.expectRevert("AA80 invalid type");
        _entryPoint.registerIntentType(newIntentType);
    }

    function test_failRegisterIntentType_alreadyRegistered() public {
        vm.expectRevert("AA81 already registered");
        _entryPoint.registerIntentType(_assetBasedIntentType);
    }

    function test_getIntentTypeContract() public {
        bytes32 typeId = _assetBasedIntentType.typeId();
        IIntentType registeredType = _entryPoint.getIntentTypeContract(typeId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentType(_assetBasedIntentType)));
        bytes32 registeredHash = keccak256(abi.encode(registeredType));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentTypeContract_unknownType() public {
        bytes32 typeId = _assetBasedIntentType.typeId();
        vm.expectRevert("AA82 unknown type");
        _entryPoint.getIntentTypeContract(typeId << 1);
    }

    function test_getIntentTypeId() public {
        bytes32 typeId = _entryPoint.getIntentTypeId(_assetBasedIntentType);
        bytes32 expectedTypeId = _assetBasedIntentType.typeId();
        assertEq(typeId, expectedTypeId);
    }

    function test_failGetIntentTypeId_unknownType() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentType newIntentType = new AssetBasedIntentType(newEntryPoint);
        vm.expectRevert("AA82 unknown standtypeard");
        newEntryPoint.getIntentTypeId(newIntentType);
    }
}
