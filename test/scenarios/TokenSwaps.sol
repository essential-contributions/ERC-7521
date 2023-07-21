// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user is specifying different tokens to release and tokens expected by the end.
 *
 * Solution:
 * 1. the solver swaps the released tokens for the desired tokens and pockets the difference
 */
contract TokenSwaps is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), 100 ether);
        vm.deal(address(_account), 100 ether);

        //set specific block.timestamp
        vm.warp(1000);
    }

    function test_constantRelease() public {
        //create account intent (curve should evaluate as 9ether at timestamp 1000)
        UserIntent memory userIntent = _createIntent("", "");
        userIntent = userIntent.addReleaseERC20(address(_testERC20), constantCurve(10 ether));
        userIntent = userIntent.addRequiredETH(linearCurve((3 ether) / 3000, 7 ether, 3000, true), true);
        userIntent = _signIntent(userIntent);

        //create solution
        IEntryPoint.SolutionStep[] memory steps1 =
            _solverSwapAllERC20ForETHAndForward(10 ether, address(_publicAddressSolver), 9 ether, address(_account));
        IEntryPoint.SolutionStep[] memory steps2;
        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userBalance = address(_account).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        assertEq(solverBalance, (1 ether) + 5, "The solver ended up with incorrect balance");
        assertEq(userBalance, 109 ether, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, 90 ether, "The user released more ERC20 tokens than expected");
    }

    function test_constantExpectation() public {
        //create account intent (curve should evaluate as 7.75ether at timestamp 1000)
        UserIntent memory userIntent = _createIntent("", "");
        userIntent =
            userIntent.addReleaseERC20(address(_testERC20), exponentialCurve(750000000000, 7 ether, 2, 2000, false));
        userIntent = userIntent.addRequiredETH(constantCurve(7 ether), true);
        userIntent = _signIntent(userIntent);

        //create solution
        IEntryPoint.SolutionStep[] memory steps1 =
            _solverSwapAllERC20ForETHAndForward(7.75 ether, address(_publicAddressSolver), 7 ether, address(_account));
        IEntryPoint.SolutionStep[] memory steps2;
        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userBalance = address(_account).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        assertEq(solverBalance, (0.75 ether) + 5, "The solver ended up with incorrect balance");
        assertEq(userBalance, 107 ether, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, 92.25 ether, "The user released more ERC20 tokens than expected");
    }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
