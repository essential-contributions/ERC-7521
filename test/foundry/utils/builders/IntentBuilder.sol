// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {UserIntent} from "../../../../src/interfaces/UserIntent.sol";

library IntentBuilder {
    /**
     * Create a new user intent with the specified parameters.
     * @param sender The address of the intent sender.
     * @param timestamp The unix time stamp (in seconds) from when this intent was signed.
     * @return intent The created user intent.
     */
    function create(address sender, uint256 timestamp) public pure returns (UserIntent memory intent) {
        bytes[] memory data;

        intent = UserIntent({sender: sender, timestamp: timestamp, intentData: data, signature: ""});
    }

    function testNothing() public {}
}
