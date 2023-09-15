// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./utils/TestEnvironment.sol";

contract UserIntentTest is TestEnvironment {
    using UserIntentLib for UserIntent;

    function test_hash() public {
        bytes32 hash = _intent().hash();
        bytes32 expectedHash = 0xaa4872a80202f9372c4d648876648b6ccfeae521363f2942832b21dfac92833f;
        assertEq(hash, expectedHash);
    }
}
