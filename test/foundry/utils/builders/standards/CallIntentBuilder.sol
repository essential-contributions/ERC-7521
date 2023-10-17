// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../../../../../src/interfaces/UserIntent.sol";
import "../../../../../src/standards/CallIntentStandard.sol";

/**
 * @title CallIntentBuilder
 * Utility functions helpful for building a call intent.
 */
library CallIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param standard The standard ID for the intent segment.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes32 standard, CallIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        bytes32[] memory standards = new bytes32[](intent.standards.length + 1);
        for (uint256 i = 0; i < intent.standards.length; i++) {
            standards[i] = intent.standards[i];
        }
        standards[intent.standards.length] = standard;
        intent.standards = standards;

        return encodeData(intent, segment);
    }

    /**
     * Encodes the call intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The call intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, CallIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        bytes[] memory intentData = intent.intentData;
        bytes[] memory newData = new bytes[](intentData.length + 1);
        for (uint256 i = 0; i < intentData.length; i++) {
            newData[i] = intentData[i];
        }
        bytes memory raw = abi.encode(segment);
        bytes memory encoded = new bytes(raw.length - 32);
        for (uint256 j = 32; j < raw.length; j++) {
            encoded[j - 32] = raw[j];
        }
        newData[intentData.length] = encoded;
        intent.intentData = newData;

        return intent;
    }

    /**
     * Decodes the call intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The call intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (CallIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        (CallIntentSegment memory decoded) = abi.decode(raw, (CallIntentSegment));
        return decoded;
    }

    function testNothing() public {}
}

/**
 * @title CallIntentSegmentBuilder
 * Utility functions helpful for building a call intent segment.
 */
library CallIntentSegmentBuilder {
    /**
     * Create a new intent segment with the specified parameters.
     * @param callData The data for an intended call.
     * @return intent The created user intent segment.
     */
    function create(bytes memory callData) public pure returns (CallIntentSegment memory) {
        return CallIntentSegment({callData: callData});
    }

    function testNothing() public {}
}
