// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user is specifying different tokens to release and tokens expected by the end.
 *
 * Solution:
 * 1. the solver swaps the released tokens for the desired tokens and pockets the difference
 */
contract TokenSwaps is ScenarioTestEnvironment {
    uint256 private _accountInitialETHBalance = 100 ether;
    uint256 private _accountInitialERC20Balance = 100 ether;

    function _constantExpectationTntent(
        uint256 erc20ReleaseAmount,
        uint256 releaseDuration,
        uint256 releaseAt,
        uint256 ethRequireAmount
    ) private view returns (UserIntent memory) {
        int256 releaseStartAmount = 0;
        int256 releaseEndAmount = int256(erc20ReleaseAmount * (releaseDuration / releaseAt));

        //build intent
        UserIntent memory intent = _intent();
        intent = _addErc20ReleaseLinear(
            intent,
            uint48(block.timestamp - releaseAt),
            uint24(releaseDuration),
            releaseStartAmount,
            releaseEndAmount - releaseStartAmount
        );
        intent = _addEthRecord(intent);
        intent = _addEthRequire(intent, int256(ethRequireAmount), true);
        intent = _addSequentialNonce(intent, 1);
        return intent;
    }

    function _constantReleaseTntent(
        uint256 erc20ReleaseAmount,
        uint256 ethRequireAmount,
        uint256 requireDuration,
        uint256 requireAt
    ) private view returns (UserIntent memory) {
        int256 requireStartAmount = 0;
        int256 requireEndAmount = int256(ethRequireAmount * (requireDuration / requireAt));

        //build intent
        UserIntent memory intent = _intent();
        intent = _addErc20Release(intent, int256(erc20ReleaseAmount));
        intent = _addEthRecord(intent);
        intent = _addEthRequireLinear(
            intent,
            uint48(block.timestamp - requireAt),
            uint24(requireDuration),
            requireStartAmount,
            requireEndAmount - requireStartAmount,
            true
        );
        intent = _addSequentialNonce(intent, 1);
        return intent;
    }

    function _solutionForCase(UserIntent memory intent, uint256 erc20ReleaseAmount, uint256 ethRequireAmount)
        private
        view
        returns (IntentSolution memory)
    {
        UserIntent memory solverIntent = _solverIntent(
            "",
            _solverSwapERC20ForETHAndForward(
                erc20ReleaseAmount, address(_publicAddressSolver), ethRequireAmount, address(_account)
            ),
            "",
            2
        );
        return _solution(intent, solverIntent);
    }

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), _accountInitialERC20Balance);
        vm.deal(address(_account), _accountInitialETHBalance);
    }

    function testFuzz_constantRelease(
        uint72 erc20ReleaseAmount,
        uint72 ethRequireAmount,
        uint16 requireDuration,
        uint16 requireAt
    ) public {
        vm.assume(0 < erc20ReleaseAmount);
        vm.assume(0 < requireDuration);
        vm.assume(0 < requireAt);
        vm.assume(requireAt < requireDuration);
        vm.assume(ethRequireAmount < erc20ReleaseAmount);
        vm.assume(erc20ReleaseAmount < _accountInitialERC20Balance);
        uint256 slippage = 5;

        //build intent, solution and execute
        {
            UserIntent memory intent =
                _constantReleaseTntent(erc20ReleaseAmount, ethRequireAmount, requireDuration, requireAt);
            intent = _signIntent(intent);

            IntentSolution memory solution = _solutionForCase(intent, erc20ReleaseAmount, ethRequireAmount);

            _entryPoint.handleIntents(solution);
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            uint256 expectedSolverBalance = (erc20ReleaseAmount - ethRequireAmount) + slippage;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = _accountInitialETHBalance + ethRequireAmount;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance = _accountInitialERC20Balance - erc20ReleaseAmount;
            assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }

    function testFuzz_constantExpectation(
        uint72 erc20ReleaseAmount,
        uint72 ethRequireAmount,
        uint16 releaseDuration,
        uint16 releaseAt
    ) public {
        vm.assume(0 < erc20ReleaseAmount);
        vm.assume(0 < releaseDuration);
        vm.assume(0 < releaseAt);
        vm.assume(releaseAt < releaseDuration);
        vm.assume(ethRequireAmount < erc20ReleaseAmount);
        vm.assume(erc20ReleaseAmount < _accountInitialERC20Balance);
        uint256 slippage = 5;

        //build intent, solution and execute
        {
            UserIntent memory intent =
                _constantReleaseTntent(erc20ReleaseAmount, ethRequireAmount, releaseDuration, releaseAt);
            intent = _signIntent(intent);

            IntentSolution memory solution = _solutionForCase(intent, erc20ReleaseAmount, ethRequireAmount);

            _entryPoint.handleIntents(solution);
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            uint256 expectedSolverBalance = (erc20ReleaseAmount - ethRequireAmount) + slippage;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = _accountInitialETHBalance + ethRequireAmount;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance = _accountInitialERC20Balance - erc20ReleaseAmount;
            assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }
}
