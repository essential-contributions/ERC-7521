// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./TestEnvironment.sol";

contract UserIntentTest is Test, TestEnvironment {
    using UserIntentLib for UserIntent;

    bytes32 constant EXPECTED_STANDARD_ID = 0xa47768038d55ae947d4e5f5b3a48b387956e249f58f093039b870e30eb7cb907;
    bytes32 constant EXPECTED_HASH = 0xacbff197b0eedca19d59b708ab54d127c8bc33b21213c25bc54bb1077d22e474;

    // gas consumption 603920
    function test_getStandard() public {
        bytes32 standard = _intent().getStandard();
        assertEq(standard, EXPECTED_STANDARD_ID);
    }

    // TODO: discuss removing `getStandard()` since it is more expensive
    // gas consumption 596377
    function test_getStandardDirectly() public {
        bytes32 standard = _intent().standard;
        assertEq(standard, EXPECTED_STANDARD_ID);
    }

    function test_hash() public {
        bytes32 hash = _intent().hash();
        assertEq(hash, EXPECTED_HASH);
    }
}
