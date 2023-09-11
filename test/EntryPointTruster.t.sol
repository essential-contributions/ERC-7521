// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../contracts/wallet/TokenCallbackHandler.sol";
import "./utils/ScenarioTestEnvironment.sol";

contract EntryPointTrusterTest is ScenarioTestEnvironment {
    function test_failOnlyFromIntentStandardExecutingForSender_notExecutingIntent() public {
        //fund account
        _testERC20.mint(address(_account), 100 ether);

        bytes memory mintCall = abi.encodeWithSelector(TestERC20.mint.selector, address(_account), 1 ether);

        vm.prank(address(_assetBasedIntentStandard));
        vm.expectRevert("EntryPoint not executing intent for sender");
        _account.execute(address(_testERC20), 0, mintCall);
    }
}
