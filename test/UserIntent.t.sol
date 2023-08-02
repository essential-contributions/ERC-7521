// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./TestEnvironment.sol";

contract UserIntentTest is Test, TestEnvironment {
    using UserIntentLib for UserIntent;

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
        bytes32 expectedHash = 0xdf3a356c91c688a30fb696a58e3f662ebc0318dccc0c1ef399b664cdd93e1be0;
        assertEq(hash, expectedHash);
    }
}
