// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import {DefaultIntentData} from "../src/standards/default/DefaultIntentData.sol";
import {DefaultIntentStandard} from "../src/standards/default/DefaultIntentStandard.sol";
import "./utils/DefaultIntentBuilder.sol";
import "./utils/ScenarioTestEnvironment.sol";

contract DefaultIntentStandardTest is ScenarioTestEnvironment {
    function test_empty() public {
        DefaultIntentData memory defaultIntentData = DefaultIntentData({callData: "", callGasLimit: 1000000});

        (bytes32 defaultIntentStandardId,) = IEntryPoint(_entryPoint).getDefaultIntentStandard();

        // create intent
        UserIntent memory intent =
            DefaultIntentBuilder.create(defaultIntentStandardId, defaultIntentData, address(_account), 0, 0);
        intent = _signIntent(intent);

        // create solution
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        // execute
        _entryPoint.handleIntents(solution);
    }

    function test_claimAirdrop() public {
        uint256 claimAmount = 1 ether;
        DefaultIntentData memory defaultIntentData =
            DefaultIntentData({callData: _accountClaimAirdropERC20(claimAmount), callGasLimit: 1000000});

        (bytes32 defaultIntentStandardId,) = IEntryPoint(_entryPoint).getDefaultIntentStandard();

        // create intent
        UserIntent memory intent =
            DefaultIntentBuilder.create(defaultIntentStandardId, defaultIntentData, address(_account), 0, 0);
        intent = _signIntent(intent);

        // create solution
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        // execute
        _entryPoint.handleIntents(solution);

        // verify end state
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        assertEq(userERC20Tokens, claimAmount, "The user did not receive correct amount of ERC20 from airdrop");
    }

    function test_fail() public {
        DefaultIntentData memory defaultIntentData =
            DefaultIntentData({callData: _accountBuyERC721(1 ether), callGasLimit: 1000000});

        (bytes32 defaultIntentStandardId,) = IEntryPoint(_entryPoint).getDefaultIntentStandard();

        //create intent
        UserIntent memory intent =
            DefaultIntentBuilder.create(defaultIntentStandardId, defaultIntentData, address(_account), 0, 0);
        intent = _signIntent(intent);

        // create solution
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        // execute
        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }
}
