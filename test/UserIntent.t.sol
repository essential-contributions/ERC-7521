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
        bytes32 expectedHash = 0x90645ef023783c203bd0c4a0107b3d92c35c3b5b20455fc91952ac722f248a71;
        assertEq(hash, expectedHash);
    }
}
