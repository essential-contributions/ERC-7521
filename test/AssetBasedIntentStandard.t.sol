// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/ScenarioTestEnvironment.sol";

contract AssetBasedIntentStandardTest is ScenarioTestEnvironment {
    function test_entryPoint() public {
        assertEq(address(_intentStandard.entryPoint()), address(_entryPoint));
    }
}
