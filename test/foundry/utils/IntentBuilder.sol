// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {UserIntent} from "../../../src/interfaces/UserIntent.sol";

library IntentBuilder {
    /**
     * Create a new user intent with the specified parameters.
     * @param sender The address of the intent sender.
     * @return intent The created user intent.
     */
    function create(address sender) public pure returns (UserIntent memory intent) {
        bytes[] memory data;

        intent = UserIntent({sender: sender, intentData: data, signature: ""});
    }

    /**
     * Encodes the sequential nonce segment onto the user intent.
     * @param intent The user intent to modify.
     * @param segmentData The segment data to encode.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes memory segmentData) public pure returns (UserIntent memory) {
        bytes[] memory intentData = intent.intentData;
        bytes[] memory newData = new bytes[](intentData.length + 1);
        for (uint256 i = 0; i < intentData.length; i++) {
            newData[i] = intentData[i];
        }
        newData[intentData.length] = segmentData;
        intent.intentData = newData;

        return intent;
    }
}
