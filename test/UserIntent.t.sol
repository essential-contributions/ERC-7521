// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./utils/TestEnvironment.sol";

contract UserIntentTest is TestEnvironment {
    using UserIntentLib for UserIntent;

    function test_hash() public {
        bytes32 hash = _intent().hash();
        bytes32 expectedHash = 0xf3da44c1f75ff80140830044acc8c7b3edf7804ae18756e9f35ef6633718bd03;
        assertEq(hash, expectedHash);
    }
}
