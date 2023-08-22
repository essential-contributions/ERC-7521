// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../../src/interfaces/UserIntent.sol";
import "../../src/standards/default/DefaultIntentStandard.sol";
import "../../src/standards/default/DefaultIntentData.sol";

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
    function create(bytes32 standard, DefaultIntentData memory data, address sender, uint256 nonce, uint256 timestamp)
        public
        pure
        returns (UserIntent memory intent)
    {
        intent = UserIntent({
            standard: standard,
            sender: sender,
            nonce: nonce,
            timestamp: timestamp,
            verificationGasLimit: 1000000,
            intentData: "",
            signature: ""
        });
        intent = encodeData(intent, data);
    }

    /**
     * Encodes the default intent data onto the user intent.
     * @param intent The user intent to modify.
     * @param data The default intent standard data.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, DefaultIntentData memory data)
        public
        pure
        returns (UserIntent memory)
    {
        bytes memory raw = abi.encode(data);
        bytes memory encoded = new bytes(raw.length - 32);
        for (uint256 i = 32; i < raw.length; i++) {
            encoded[i - 32] = raw[i];
        }

        intent.intentData = encoded;
        return intent;
    }
}
