// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import "../src/interfaces/UserIntent.sol";
import "./TestUtil.sol";

contract UserIntentTest is Test, TestUtil {
    using UserIntentLib for UserIntent;

    // gas consumption 17719
    function test_getStandard() public {
        bytes32 standard = userIntent.getStandard();
        assertEq(standard, STANDARD_ID);
        userIntent.standard;
    }

    // TODO: discuss
    // gas consumption 2361
    function test_getStandardDirectly() public {
        bytes32 standard = userIntent.standard;
        assertEq(standard, STANDARD_ID);
    }

    function test_hash() public {
        bytes32 hash = userIntent.hash();
        bytes32 expectedHash = 0xbe9fe352c4139c62140a45927b8b491dd231b947b3c2c8ad95538a9fda06dba4;
        assertEq(hash, expectedHash);
    }
}
