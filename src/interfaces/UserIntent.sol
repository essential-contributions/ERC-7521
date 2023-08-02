// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_calldataKeccak} from "../utils/Helpers.sol";

/**
 * User Intent struct
 * @param standard the intent standard (type/format).
 * @param sender the sender account of this request.
 * @param nonce unique value the sender uses to verify it is not a replay.
 * @param timestamp the time when the intent was created.
 * @param verificationGasLimit max gas to be spent on intent verification.
 * @param intentData the intent data specific to the intents standard.
 * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct UserIntent {
    bytes32 standard;
    address sender;
    uint256 nonce;
    uint256 timestamp;
    uint256 verificationGasLimit;
    bytes intentData;
    bytes signature;
}

/**
 * Utility functions helpful when working with UserIntent structs.
 */
library UserIntentLib {
    function getStandard(UserIntent calldata intent) public pure returns (bytes32) {
        bytes32 data;
        //read intent standard from intent, which is first intent member (saves 800 gas...)
        assembly {
            data := calldataload(intent)
        }
        return bytes32(data);
    }

    function hash(UserIntent calldata intent) public pure returns (bytes32) {
        return keccak256(_pack(intent));
    }

    function _pack(UserIntent calldata intent) private pure returns (bytes memory ret) {
        bytes32 standard = getStandard(intent);
        address sender = intent.sender;
        uint256 nonce = intent.nonce;
        uint256 timestamp = intent.timestamp;
        uint256 verificationGasLimit = intent.verificationGasLimit;
        bytes32 intentDataHash = _calldataKeccak(intent.intentData);

        return abi.encode(standard, sender, nonce, timestamp, verificationGasLimit, intentDataHash);
    }
}
