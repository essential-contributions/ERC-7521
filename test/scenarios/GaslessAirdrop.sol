// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to claim airdropped ERC20 tokens but wants to pay for gas
 * with some of the tokens they just received.
 *
 * Intent Action: user claims the ERC20 airdrop and releases some of them for the solver
 *
 * Solution:
 * 1. the solver takes the users released ERC20s and swaps them all to wrappedETH
 * 2. the solver unwraps all to ETH and moves them to their own wallet
 */
contract GaslessAirdrop is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;

    function setUp() public override {
        super.setUp();
    }

    function test_gaslessAirdrop() public {
        //create account intent
        bytes memory intentCallData1 = _accountClaimAirdropERC20(100 ether);
        bytes memory intentCallData2;

        UserIntent memory userIntent = _createIntent(intentCallData1, intentCallData2);
        userIntent = userIntent.addReleaseERC20(address(_testERC20), constantCurve(2 ether));
        userIntent = _signIntent(userIntent);

        //create solution
        IEntryPoint.SolutionStep[] memory steps1 = _solverSwapAllERC20ForETH(2 ether, address(_publicAddressSolver));
        IEntryPoint.SolutionStep[] memory steps2;

        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        assertEq(solverBalance, (2 ether) + 5, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, 98 ether, "The user released more ERC20 tokens than expected");
    }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
