// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * User Intent struct
 * @param standard the intent standard (type/format).
 * @param sender the sender account of this request.
 * @param nonce unique value the sender uses to verify it is not a replay.
 * @param timestamp the time when the intent was created.
 * @param intentData the intent data specific to the intents standard.
 * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct UserIntent {
    bytes32 standard;
    address sender;
    uint256 nonce;
    uint256 timestamp;
    bytes[] intentData;
    bytes signature;
}

/**
 * Utility functions helpful when working with UserIntent structs.
 */
library UserIntentLib {
    function hash(UserIntent calldata intent) public pure returns (bytes32) {
        return keccak256(_pack(intent));
    }

    function _pack(UserIntent calldata intent) private pure returns (bytes memory ret) {
        bytes32 standard = intent.standard;
        address sender = intent.sender;
        uint256 nonce = intent.nonce;
        uint256 timestamp = intent.timestamp;
        bytes32 intentDataHash = keccak256(abi.encode(intent.intentData));

        return abi.encode(standard, sender, nonce, timestamp, intentDataHash);
    }
}
