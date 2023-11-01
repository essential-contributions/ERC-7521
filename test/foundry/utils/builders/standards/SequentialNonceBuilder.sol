// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../../../../../src/interfaces/UserIntent.sol";
import "../../../../../src/standards/SequentialNonce.sol";

/**
 * @title SequentialNonceBuilder
 * Utility functions helpful for building a sequential nonce.
 */
library SequentialNonceBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, SequentialNonceSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        return encodeData(intent, segment);
    }

    /**
     * Encodes the sequential nonce segment onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The user operation segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, SequentialNonceSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        bytes[] memory intentData = intent.intentData;
        bytes[] memory newData = new bytes[](intentData.length + 1);
        for (uint256 i = 0; i < intentData.length; i++) {
            newData[i] = intentData[i];
        }
        newData[intentData.length] = abi.encode(segment);
        intent.intentData = newData;

        return intent;
    }

    /**
     * Decodes the sequential nonce segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The nonce data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (SequentialNonceSegment memory)
    {
        (SequentialNonceSegment memory decoded) = abi.decode(intent.intentData[segmentIndex], (SequentialNonceSegment));
        return decoded;
    }

    function testNothing() public {}
}

/**
 * @title SequentialNonceSegmentBuilder
 * Utility functions helpful for building a sequential nonce segment.
 */
library SequentialNonceSegmentBuilder {
    /**
     * Create a new intent segment with the specified parameters.
     * @param standard The standard ID for the intent segment.
     * @param nonce The nonce value.
     * @return intent The created user intent segment.
     */
    function create(bytes32 standard, uint256 nonce) public pure returns (SequentialNonceSegment memory) {
        return SequentialNonceSegment({standard: standard, nonce: nonce});
    }

    function testNothing() public {}
}
