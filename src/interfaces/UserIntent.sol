// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * User Intent struct
 * @param sender the sender account of this request.
 * @param timestamp the time when the intent was created.
 * @param intentData the intent data specific to the intents standard.
 * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct UserIntent {
    address sender;
    bytes[] intentData;
    bytes signature;
}

/**
 * Utility functions helpful when working with UserIntent structs.
 */
library UserIntentLib {
    function hash(UserIntent calldata intent) internal pure returns (bytes32) {
        return keccak256(_pack(intent));
    }

    function _pack(UserIntent calldata intent) private pure returns (bytes memory ret) {
        address sender = intent.sender;
        bytes32 intentDataHash = keccak256(abi.encode(intent.intentData));

        return abi.encode(sender, intentDataHash);
    }
}
