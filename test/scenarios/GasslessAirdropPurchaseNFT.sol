// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to buy an ERC1155 NFT using yet to claim aridropped ERC20 tokens
 * but they need native tokens to do the purchase.
 *
 * Intent Action Part1: user claims the ERC20 airdrop and releases some of them for the solver
 *
 * Solution:
 * 1. the solver takes the users released ERC20s and swaps them all to wrappedETH
 * 2. all wrappedETH is unwrapped and enough ETH is forwarded to the user account to cover the purchase
 * 3. the solver takes the remaining ETH
 *
 * Intent Action Part2: user account makes the intended purchase with the newly received ETH
 */
contract GasslessAirdropPurchaseNFT is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;

    function setUp() public override {
        super.setUp();
    }

    function test_gasslessAirdropPurchaseNFT() public {
        //create account intent
        bytes memory intentCallData1 = _accountClaimAirdropERC20(100 ether);
        bytes memory intentCallData2 = _accountBuyERC1155(1 ether);

        UserIntent memory userIntent = _createIntent(intentCallData1, intentCallData2);
        userIntent = userIntent.addReleaseERC20(address(_testERC20), constantCurve(2 ether));
        userIntent = userIntent.addRequiredETH(constantCurve(0), false);
        userIntent = _signIntent(userIntent);

        //create solution
        IEntryPoint.SolutionStep[] memory steps1 =
            _solverSwapAllERC20ForETHAndForward(2 ether, address(_publicAddressSolver), 1 ether, address(_account));
        IEntryPoint.SolutionStep[] memory steps2;

        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(solverBalance, (1 ether) + 5, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, 98 ether, "The user released more ERC20 tokens than expected");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
