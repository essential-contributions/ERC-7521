// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/wallet/TokenCallbackHandler.sol";
import "./utils/ScenarioTestEnvironment.sol";

contract EntryPointTrusterTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), 100 ether);
    }

    function test_failOnlyFromIntentStandardExecutingForSender_notRegistered() public {
        // TODO
    }

    function test_failOnlyFromIntentStandardExecutingForSender_notExecutingIntent() public {
        bytes memory mintCall = abi.encodeWithSelector(TestERC20.mint.selector, address(_account), 1 ether);

        vm.prank(address(_intentStandard));
        vm.expectRevert("EntryPoint not executing intent");
        _account.execute(address(_testERC20), 0, mintCall);
    }

    function test_failOnlyFromIntentStandardExecutingForSender_intentStandardMismatch() public {
        // TODO
    }
}
