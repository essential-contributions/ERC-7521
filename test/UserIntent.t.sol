// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./TestEnvironment.sol";

contract UserIntentTest is Test, TestEnvironment {
    using UserIntentLib for UserIntent;

    function test_hash() public {
        bytes32 hash = _intent().hash();
        bytes32 expectedHash = 0xdf3a356c91c688a30fb696a58e3f662ebc0318dccc0c1ef399b664cdd93e1be0;
        assertEq(hash, expectedHash);
    }
}

