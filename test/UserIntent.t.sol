// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./utils/TestEnvironment.sol";

contract UserIntentTest is TestEnvironment {
    using UserIntentLib for UserIntent;

    function test_hash() public {
        bytes32 hash = _intent().hash();
        bytes32 expectedHash = 0x23b1cd4046df6a3e0c60acdd0a06b842d154894098cd6b9374687458ecf99599;
        assertEq(hash, expectedHash);
    }
}
