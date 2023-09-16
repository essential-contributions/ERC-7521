// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../src/wallet/TokenCallbackHandler.sol";
import "./utils/ScenarioTestEnvironment.sol";

contract EntryPointTrusterTest is ScenarioTestEnvironment {
    function test_failOnlyFromIntentTypeExecutingForSender_notExecutingIntent() public {
        //fund account
        _testERC20.mint(address(_account), 100 ether);

        bytes memory mintCall = abi.encodeWithSelector(TestERC20.mint.selector, address(_account), 1 ether);

        vm.prank(address(_assetBasedIntentType));
        vm.expectRevert("EntryPoint not executing intent type for sender");
        _account.execute(address(_testERC20), 0, mintCall);
    }
}
