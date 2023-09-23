// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import {OperationIntentSegment} from "../src/standards/operation/OperationIntentSegment.sol";
import {OperationIntentStandard} from "../src/standards/operation/OperationIntentStandard.sol";
import "./utils/OperationIntentBuilder.sol";
import "./utils/ScenarioTestEnvironment.sol";

contract OperationIntentStandardTest is ScenarioTestEnvironment {
    using OperationIntentBuilder for UserIntent;

    bytes32 private _operationIntentStandardId;

    function setUp() public override {
        super.setUp();
        _operationIntentStandardId = IEntryPoint(_entryPoint).getOperationIntentStandardId();
    }

    function test_empty() public {
        // create intent
        UserIntent memory intent = OperationIntentBuilder.create(_operationIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment("");
        intent = _signIntent(intent);

        // create solution
        IntentSolution memory solution = _singleIntentSolution(intent);

        // execute
        _entryPoint.handleIntents(solution);
    }

    function test_singleSegment() public {
        uint256 claimAmount = 1 ether;

        // create intent
        UserIntent memory intent = OperationIntentBuilder.create(_operationIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(_accountClaimAirdropERC20(claimAmount));
        intent = _signIntent(intent);

        // create solution
        IntentSolution memory solution = _singleIntentSolution(intent);

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

        // create intent
        UserIntent memory intent = OperationIntentBuilder.create(_operationIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(_accountClaimAirdropERC20(claimAmount));
        intent = intent.addSegment(_accountBuyERC1155(nftPrice));
        intent = _signIntent(intent);

        // create solution
        IntentSolution memory solution = _singleIntentSolution(intent);

        // execute
        _entryPoint.handleIntents(solution);

        // verify end state
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(userERC20Tokens, claimAmount, "The user did not receive correct amount of ERC20 from airdrop");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    function test_fail() public {
        //create intent
        UserIntent memory intent = OperationIntentBuilder.create(_operationIntentStandardId, address(_account), 0, 0);
        intent = intent.addSegment(_accountBuyERC721(1 ether));
        intent = _signIntent(intent);

        // create solution
        IntentSolution memory solution = _singleIntentSolution(intent);

        // execute
        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }
}
