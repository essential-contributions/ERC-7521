// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {UserIntent} from "../../../../src/interfaces/UserIntent.sol";

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
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
