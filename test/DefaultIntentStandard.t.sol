// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import {DefaultIntentSegment} from "../src/standards/default/DefaultIntentSegment.sol";
import {DefaultIntentStandard} from "../src/standards/default/DefaultIntentStandard.sol";
import "./utils/DefaultIntentBuilder.sol";
import "./utils/ScenarioTestEnvironment.sol";

contract DefaultIntentStandardTest is ScenarioTestEnvironment {
    using DefaultIntentBuilder for UserIntent;

    bytes32 private _defaultIntentStandardId;

    function setUp() public override {
        super.setUp();
        _defaultIntentStandardId = IEntryPoint(_entryPoint).getDefaultIntentStandardId();
    }

    function test_empty() public {
        DefaultIntentSegment memory intentSegment = DefaultIntentSegment({callData: "", callGasLimit: 1000000});

        // create intent
        UserIntent memory intent = DefaultIntentBuilder.create(_defaultIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(intentSegment);
        intent = _signIntent(intent);

        // create solution
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        // execute
        _entryPoint.handleIntents(solution);
    }

    function test_singleSegment() public {
        uint256 claimAmount = 1 ether;

        DefaultIntentSegment memory intentSegment =
            DefaultIntentSegment({callData: _accountClaimAirdropERC20(claimAmount), callGasLimit: 1000000});

        // create intent
        UserIntent memory intent = DefaultIntentBuilder.create(_defaultIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(intentSegment);
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

    function test_multipleSegments() public {
        uint256 claimAmount = 2 ether;
        uint256 nftPrice = 1 ether;

        vm.deal(address(_account), nftPrice);

        DefaultIntentSegment memory intentSegment2 =
            DefaultIntentSegment({callData: _accountBuyERC1155(nftPrice), callGasLimit: 1000000});
        DefaultIntentSegment memory intentSegment1 =
            DefaultIntentSegment({callData: _accountClaimAirdropERC20(claimAmount), callGasLimit: 1000000});

        // create intent
        UserIntent memory intent = DefaultIntentBuilder.create(_defaultIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(intentSegment1);
        intent = intent.addSegment(intentSegment2);
        intent = _signIntent(intent);

        // create solution
        IEntryPoint.IntentSolution memory solution =
            _solution(_singleIntent(intent), _noSteps(), _noSteps(), _noSteps());

        // execute
        _entryPoint.handleIntents(solution);

        // verify end state
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(userERC20Tokens, claimAmount, "The user did not receive correct amount of ERC20 from airdrop");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    function test_fail() public {
        DefaultIntentSegment memory intentSegment =
            DefaultIntentSegment({callData: _accountBuyERC721(1 ether), callGasLimit: 1000000});

        //create intent
        UserIntent memory intent = DefaultIntentBuilder.create(_defaultIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(intentSegment);
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
