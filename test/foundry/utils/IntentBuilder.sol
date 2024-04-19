// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {UserIntent} from "../../../contracts/interfaces/UserIntent.sol";

library IntentBuilder {
    /**
     * Create a new user intent with the specified parameters.
     * @param sender The address of the intent sender.
     * @return intent The created user intent.
     */
    function create(address sender) public pure returns (UserIntent memory intent) {
        bytes[] memory data;

        intent = UserIntent({sender: sender, segments: data, signature: ""});
    }

    /**
     * Encodes the sequential nonce segment onto the user intent.
     * @param intent The user intent to modify.
     * @param segmentData The segment data to encode.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes memory segmentData) public pure returns (UserIntent memory) {
        bytes[] memory segments = intent.segments;
        bytes[] memory newData = new bytes[](segments.length + 1);
        for (uint256 i = 0; i < segments.length; i++) {
            newData[i] = segments[i];
        }
        newData[segments.length] = segmentData;
        intent.segments = newData;

        return intent;
    }
}
