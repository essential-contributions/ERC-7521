// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "../utils/TestEnvironment.sol";
import "../../../src/standards/utils/CurveCoder.sol";

/*
 * In this scenario, a user is specifying different tokens to release and tokens expected by the end.
 *
 * Solution:
 * 1. the solver swaps the released tokens for the desired tokens and pockets the difference
 */
abstract contract TokenSwapScenario is TestEnvironment {
    uint256 private _accountInitialETHBalance = 100 ether;
    uint256 private _accountInitialERC20Balance = 100 ether;

    function tokenSwap_setUp() public {
        //fund accounts
        _testERC20.mint(address(_account), _accountInitialERC20Balance);
        vm.deal(address(_account), _accountInitialETHBalance);
        _testERC20.mint(address(_account2), _accountInitialERC20Balance);
        vm.deal(address(_account2), _accountInitialETHBalance);
        _testERC20.mint(address(_account3), _accountInitialERC20Balance);
        vm.deal(address(_account3), _accountInitialETHBalance);
        _testERC20.mint(address(_account4), _accountInitialERC20Balance);
        vm.deal(address(_account4), _accountInitialETHBalance);

        //set block timestamp to something reasonable
        vm.warp(1700952587);
    }

    function tokenSwap_run(bool constantRelease)
        public
        returns (uint256 erc20ReleaseAmount, uint256 ethRequireAmount, uint256 slippage)
    {
        erc20ReleaseAmount = 1 ether;
        ethRequireAmount = 0.9 ether;
        slippage = 5;
        uint256 duration = 3000;
        uint256 evaluateAt = 1000;

        //build intent
        UserIntent memory intent;
        if (constantRelease) {
            intent = _constantReleaseIntent(erc20ReleaseAmount, ethRequireAmount, duration, evaluateAt);
        } else {
            intent = _constantExpectationIntent(erc20ReleaseAmount, ethRequireAmount, duration, evaluateAt);
        }
        intent = _signIntent(intent);

        //build solution
        IntentSolution memory solution = _solutionForTokenSwap(intent, erc20ReleaseAmount, ethRequireAmount);

        //execute
        _entryPoint.handleIntents(solution);
    }

    ///////////////////////////////
    // Private Builder Functions //
    ///////////////////////////////

    function _constantExpectationIntent(
        uint256 erc20ReleaseAmount,
        uint256 ethRequireAmount,
        uint256 releaseDuration,
        uint256 releaseAt
    ) private view returns (UserIntent memory) {
        int256 releaseStartAmount = 0;
        int256 releaseEndAmount = int256((erc20ReleaseAmount * releaseDuration) / releaseAt);

        //build intent
        UserIntent memory intent = _intent();
        intent = _addSequentialNonce(intent, 1);
        intent = _addEthRecord(intent, false);
        intent = _addErc20ReleaseLinear(
            intent,
            uint32(block.timestamp - releaseAt),
            uint16(releaseDuration),
            releaseStartAmount,
            (releaseEndAmount - releaseStartAmount) / int256(releaseDuration),
            false
        );
        intent = _addEthRequire(intent, int256(ethRequireAmount), true, false);
        return intent;
    }

    function _constantReleaseIntent(
        uint256 erc20ReleaseAmount,
        uint256 ethRequireAmount,
        uint256 requireDuration,
        uint256 requireAt
    ) private view returns (UserIntent memory) {
        int256 requireStartAmount = 0;
        int256 requireEndAmount = int256((ethRequireAmount * requireDuration) / requireAt);

        //build intent
        UserIntent memory intent = _intent();
        intent = _addSequentialNonce(intent, 1);
        intent = _addEthRecord(intent, false);
        intent = _addErc20Release(intent, int256(erc20ReleaseAmount), false);
        intent = _addEthRequireLinear(
            intent,
            uint32(block.timestamp - requireAt),
            uint16(requireDuration),
            requireStartAmount,
            (requireEndAmount - requireStartAmount) / int256(requireDuration),
            true,
            false
        );
        return intent;
    }

    function _solutionForTokenSwap(UserIntent memory intent, uint256 erc20ReleaseAmount, uint256 ethRequireAmount)
        private
        view
        returns (IntentSolution memory)
    {
        bytes memory solve = _solverSwapERC20ForETHAndForward(
            erc20ReleaseAmount, address(_publicAddressSolver), ethRequireAmount, address(_account)
        );
        UserIntent memory solverIntent = _solverIntent();
        solverIntent = _addSimpleCall(solverIntent, solve);
        uint256[] memory order = new uint256[](5);
        order[0] = 0;
        order[1] = 0;
        order[2] = 0;
        order[3] = 1;
        order[4] = 0;
        return _solution(intent, solverIntent, order);
    }
}
