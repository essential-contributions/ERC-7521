// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../../src/interfaces/UserIntent.sol";
import "../../src/standards/default/DefaultIntentStandard.sol";
import "../../src/standards/default/DefaultIntentSegment.sol";

/**
 * @title DefaultIntentBuilder
 * Utility functions helpful for building a default intent.
 */
library DefaultIntentBuilder {
    /**
     * Create a new user intent with the specified parameters.
     * @param standard The standard ID for the intent.
     * @param sender The address of the intent sender.
     * @param nonce The nonce to prevent replay attacks.
     * @param timestamp The unix time stamp (in seconds) from when this intent was signed.
     * @return intent The created user intent.
     */
    function create(bytes32 standard, address sender, uint256 nonce, uint256 timestamp)
        public
        pure
        returns (UserIntent memory intent)
    {
        bytes[] memory data;

        intent = UserIntent({
            standard: standard,
            sender: sender,
            nonce: nonce,
            timestamp: timestamp,
            verificationGasLimit: 1000000,
            intentData: data,
            signature: ""
        });
    }

    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, DefaultIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        DefaultIntentSegment[] memory currentSegments = decodeData(intent);

        //clone previous array and add new element
        DefaultIntentSegment[] memory segments = new DefaultIntentSegment[](currentSegments.length + 1);
        for (uint256 i = 0; i < currentSegments.length; i++) {
            segments[i] = currentSegments[i];
        }
        segments[currentSegments.length] = segment;

        return encodeData(intent, segments);
    }

    /**
     * Encodes the default intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segments The default intent standard segments.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, DefaultIntentSegment[] memory segments)
        public
        pure
        returns (UserIntent memory)
    {
        intent.intentData = new bytes[](segments.length);
        for (uint256 i = 0; i < segments.length; i++) {
            bytes memory raw = abi.encode(segments[i]);
            bytes memory encoded = new bytes(raw.length - 32);
            for (uint256 j = 32; j < raw.length; j++) {
                encoded[j - 32] = raw[j];
            }

            intent.intentData[i] = encoded;
        }
        return intent;
    }

    /**
     * Decodes the default intent segments from the user intent.
     * @param intent The user intent to decode data from.
     * @return The default intent data.
     */
    function decodeData(UserIntent memory intent) public pure returns (DefaultIntentSegment[] memory) {
        DefaultIntentSegment[] memory segments = new DefaultIntentSegment[](intent.intentData.length);
        for (uint256 i = 0; i < intent.intentData.length; i++) {
            bytes memory raw = new bytes(intent.intentData[i].length + 32);
            assembly {
                mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
            }
            for (uint256 j = 0; j < intent.intentData[i].length; j++) {
                raw[j + 32] = intent.intentData[i][j];
            }
            (DefaultIntentSegment memory decoded) = abi.decode(raw, (DefaultIntentSegment));
            segments[i] = decoded;
        }
        return segments;
    }
}
