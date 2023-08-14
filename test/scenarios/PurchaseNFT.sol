// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to buy an ERC1155 NFT using their ERC20 tokens but they need 
 * native tokens to do so.
 *
 * Solution:
 * 1. the solver takes the users released ERC20s and swaps them all to wrappedETH
 * 2. all wrappedETH is unwrapped and enough ETH is forwarded to the user account to cover the purchase
 * 3. the solver takes the remaining ETH
 *
 * Intent Action: user account makes the intended purchase with the newly received ETH
 */
contract PurchaseNFT is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), 1000 ether);
    }

    function test_purchaseNFT() public {
        //create account intent
        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment("").releaseERC20(address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(2 ether))
        );
        intent = intent.addSegment(_segment(_accountBuyERC1155(1 ether)));
        intent = intent.addSegment(_segment("").requireETH(AssetBasedIntentCurveBuilder.constantCurve(0), false));
        intent = _signIntent(intent);

        //create solution
        bytes[] memory steps1 =
            _solverSwapAllERC20ForETHAndForward(2 ether, address(_publicAddressSolver), 1 ether, address(_account));
        IEntryPoint.IntentSolution memory solution = _solution(intent, steps1, _noSteps(), _noSteps());

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(solverBalance, (1 ether) + 5, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, 998 ether, "The user released more ERC20 tokens than expected");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
