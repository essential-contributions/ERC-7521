// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "./utils/TokenSwapScenario.sol";

/*
 * Runs tests for more complex scenarios
 */
contract TokenSwapping is TokenSwapScenario {
    function setUp() public override {
        super.setUp();
        super.tokenSwap_setUp();
    }

    function test_tokenSwap() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage) = tokenSwap_run(false);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 expectedSolverBalance = (erc20ReleaseAmount - ethRequireAmount) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = accountInitialETHBalance + ethRequireAmount;
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 expectedUserERC20Balance = accountInitialERC20Balance - erc20ReleaseAmount;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
    }

    function test_tokenSwap_constantRelease() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage) = tokenSwap_run(true);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 expectedSolverBalance = (erc20ReleaseAmount - ethRequireAmount) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = accountInitialETHBalance + ethRequireAmount;
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 expectedUserERC20Balance = accountInitialERC20Balance - erc20ReleaseAmount;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
    }
}
