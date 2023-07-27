// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./TestEnvironment.sol";

contract UserIntentTest is Test, TestEnvironment {
    using UserIntentLib for UserIntent;

    bytes32 constant EXPECTED_HASH = 0xacbff197b0eedca19d59b708ab54d127c8bc33b21213c25bc54bb1077d22e474;

    // gas: 604680
    function test_getStandard() public {
        bytes32 standard = _intent().getStandard();
        assertEq(standard, _intentStandard.standardId());
    }

    // TODO: discuss removing `getStandard()` since it is more expensive
    // gas: 597122
    function test_getStandardDirectly() public {
        bytes32 standard = _intent().standard;
        assertEq(standard, _intentStandard.standardId());
    }

    // gas: 605385 whether `hash` uses `getStandard()` or `standard`
    function test_hash() public {
        bytes32 hash = _intent().hash();
        assertEq(hash, EXPECTED_HASH);
    }
}
