// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./utils/TestEnvironment.sol";

contract UserIntentTest is TestEnvironment {
    using UserIntentLib for UserIntent;

    function test_hash() public {
        bytes32 hash = _intent().hash();
        bytes32 expectedHash = 0xe1cd98550ecfbeb284feadf63b27f561ea6a07c36fb4e9d10a9260174609d5f3;
        assertEq(hash, expectedHash);
    }
}
