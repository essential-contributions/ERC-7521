// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/interfaces/UserIntent.sol";
import "./utils/TestEnvironment.sol";

contract UserIntentTest is TestEnvironment {
    using UserIntentLib for UserIntent;

    function test_hash() public {
        bytes32 hash = _intent().hash();
        bytes32 expectedHash = 0x1889a3458c8221d4b056237693cbe92c6695ac33bc191065aa3171be824b724f;
        assertEq(hash, expectedHash);
    }
}
