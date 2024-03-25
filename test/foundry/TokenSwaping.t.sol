// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

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
        (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage) =
            tokenSwap_run(false, false, false, false);

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

    function test_tokenSwap_constantExpectation() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage) =
            tokenSwap_run(true, false, false, false);

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

    function test_tokenSwap_ethToErc20() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 ethReleaseAmount, uint256 erc20RequireAmount, uint256 slippage) =
            tokenSwap_run(false, true, false, false);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(address(_publicAddressSolver));
        uint256 expectedSolverBalance = (ethReleaseAmount - erc20RequireAmount) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 expectedUserERC20Balance = accountInitialERC20Balance + erc20RequireAmount;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = accountInitialETHBalance - ethReleaseAmount;
        assertEq(userBalance, expectedUserBalance, "The user released more ETH than expected");
    }

    function test_tokenSwap_registeredStandards() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage) =
            tokenSwap_run(false, false, true, false);

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

    function test_tokenSwap_ethToErc20WithRegisteredStandards() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 ethReleaseAmount, uint256 erc20RequireAmount, uint256 slippage) =
            tokenSwap_run(false, true, true, false);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(address(_publicAddressSolver));
        uint256 expectedSolverBalance = (ethReleaseAmount - erc20RequireAmount) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 expectedUserERC20Balance = accountInitialERC20Balance + erc20RequireAmount;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = accountInitialETHBalance - ethReleaseAmount;
        assertEq(userBalance, expectedUserBalance, "The user released more ETH than expected");
    }

    function test_tokenSwap_asProxy() public {
        uint256 accountInitialETHBalance = address(_publicAddress).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_publicAddress));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage) =
            tokenSwap_run(false, false, false, true);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 expectedSolverBalance = (erc20ReleaseAmount - ethRequireAmount) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userBalance = address(_publicAddress).balance;
        uint256 expectedUserBalance = accountInitialETHBalance + ethRequireAmount;
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_publicAddress));
        uint256 expectedUserERC20Balance = accountInitialERC20Balance - erc20ReleaseAmount;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
    }

    function test_tokenSwap_ethToErc20AsProxy() public {
        uint256 accountInitialETHBalance = address(_account).balance;
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_publicAddress));

        //execute a swap intent
        (uint256 ethReleaseAmount, uint256 erc20RequireAmount, uint256 slippage) =
            tokenSwap_run(false, true, false, true);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(address(_publicAddressSolver));
        uint256 expectedSolverBalance = (ethReleaseAmount - erc20RequireAmount) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_publicAddress));
        uint256 expectedUserERC20Balance = accountInitialERC20Balance + erc20RequireAmount;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = accountInitialETHBalance - ethReleaseAmount;
        assertEq(userBalance, expectedUserBalance, "The user released more ETH than expected");
    }
}
