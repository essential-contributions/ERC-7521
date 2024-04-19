// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/**
 * User Intent struct
 * @param sender the sender account of this request.
 * @param timestamp the time when the intent was created.
 * @param segments the intent data specific to a segment of the intent.
 * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
 */
struct UserIntent {
    address sender;
    bytes[] segments;
    bytes signature;
}

/**
 * Utility functions helpful when working with UserIntent structs.
 */
library UserIntentLib {
    function getSegmentStandard(UserIntent calldata intent, uint256 index) internal pure returns (bytes32 standard) {
        bytes calldata data = intent.segments[index];
        assembly {
            standard := calldataload(data.offset)
        }
    }

    function hash(UserIntent calldata intent) internal pure returns (bytes32) {
        return keccak256(_pack(intent));
    }

    function _pack(UserIntent calldata intent) private pure returns (bytes memory ret) {
        address sender = intent.sender;
        bytes32 segmentsHash = keccak256(abi.encode(intent.segments));

        return abi.encode(sender, segmentsHash);
    }
}
