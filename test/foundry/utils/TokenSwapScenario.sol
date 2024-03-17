// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable func-name-mixedcase */

import "../utils/TestEnvironment.sol";
import "../../../contracts/standards/utils/CurveCoder.sol";

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

        //fund account for proxy testing
        _testERC20.mint(address(_publicAddress), _accountInitialERC20Balance);
        vm.deal(address(_publicAddress), _accountInitialETHBalance);

        //set block timestamp to something reasonable
        vm.warp(1700952587);
    }

    function tokenSwap_run(bool constantExpectation, bool ethToErc20, bool useReqisteredStandards, bool isProxy)
        public
        returns (uint256 releaseAmount, uint256 requireAmount, uint256 slippage)
    {
        releaseAmount = 1 ether;
        requireAmount = 0.9 ether;
        slippage = 5;
        uint256 duration = 3000;
        uint256 evaluateAt = 1000;

        //build intent
        UserIntent memory intent;
        if (constantExpectation) {
            intent = _constantExpectationIntent(releaseAmount, requireAmount, duration, evaluateAt, isProxy);
        } else {
            if (ethToErc20) {
                intent = _constantReleaseEthIntent(releaseAmount, requireAmount, duration, evaluateAt, isProxy);
            } else {
                intent = _constantReleaseErc20Intent(releaseAmount, requireAmount, duration, evaluateAt, isProxy);
            }
        }
        if (useReqisteredStandards) {
            intent = _useRegisteredStandards(intent);
        }
        intent = _signIntent(intent);

        //build solution
        IntentSolution memory solution;
        if (constantExpectation) {
            solution = _solutionForTokenSwap(intent, requireAmount, useReqisteredStandards, isProxy);
        } else {
            if (ethToErc20) {
                solution = _solutionForTokenSwapToErc20(intent, requireAmount, useReqisteredStandards, isProxy);
            } else {
                solution = _solutionForTokenSwap(intent, requireAmount, useReqisteredStandards, isProxy);
            }
        }

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
        uint256 releaseAt,
        bool isProxy
    ) private view returns (UserIntent memory) {
        int256 releaseStartAmount = 0;
        int256 releaseEndAmount = int256((erc20ReleaseAmount * releaseDuration) / releaseAt);

        //build intent
        UserIntent memory intent = _intent();
        intent = _addSequentialNonce(intent, 1);
        intent = _addEthRecord(intent, isProxy);
        intent = _addErc20ReleaseLinear(
            intent,
            uint32(block.timestamp - releaseAt),
            uint16(releaseDuration),
            releaseStartAmount,
            (releaseEndAmount - releaseStartAmount) / int256(releaseDuration),
            isProxy
        );
        intent = _addEthRequire(intent, int256(ethRequireAmount), true, isProxy);
        return intent;
    }

    function _constantReleaseErc20Intent(
        uint256 erc20ReleaseAmount,
        uint256 ethRequireAmount,
        uint256 requireDuration,
        uint256 requireAt,
        bool isProxy
    ) private view returns (UserIntent memory) {
        int256 requireStartAmount = 0;
        int256 requireEndAmount = int256((ethRequireAmount * requireDuration) / requireAt);

        //build intent
        UserIntent memory intent = _intent();
        intent = _addSequentialNonce(intent, 1);
        intent = _addEthRecord(intent, isProxy);
        intent = _addErc20Release(intent, int256(erc20ReleaseAmount), isProxy);
        intent = _addEthRequireLinear(
            intent,
            uint32(block.timestamp - requireAt),
            uint16(requireDuration),
            requireStartAmount,
            (requireEndAmount - requireStartAmount) / int256(requireDuration),
            true,
            isProxy
        );
        return intent;
    }

    function _constantReleaseEthIntent(
        uint256 ethReleaseAmount,
        uint256 erc20RequireAmount,
        uint256 requireDuration,
        uint256 requireAt,
        bool isProxy
    ) private view returns (UserIntent memory) {
        int256 requireStartAmount = 0;
        int256 requireEndAmount = int256((erc20RequireAmount * requireDuration) / requireAt);

        //build intent
        UserIntent memory intent = _intent();
        intent = _addSequentialNonce(intent, 1);
        intent = _addErc20Record(intent, isProxy);
        intent = _addEthRelease(intent, int256(ethReleaseAmount));
        intent = _addErc20RequireLinear(
            intent,
            uint32(block.timestamp - requireAt),
            uint16(requireDuration),
            requireStartAmount,
            (requireEndAmount - requireStartAmount) / int256(requireDuration),
            true,
            isProxy
        );
        return intent;
    }

    function _solutionForTokenSwap(
        UserIntent memory intent,
        uint256 ethRequireAmount,
        bool useReqisteredStandards,
        bool isProxy
    ) private view returns (IntentSolution memory) {
        address forwardTo;
        if (isProxy) {
            forwardTo = address(_publicAddress);
        } else {
            forwardTo = address(_account);
        }
        bytes memory solve =
            _solverSwapERC20ForETHAndForward(address(_publicAddressSolver), ethRequireAmount, forwardTo);
        UserIntent memory solverIntent = _solverIntent();
        solverIntent = _addSimpleCall(solverIntent, solve);
        uint256[] memory order = new uint256[](5);
        order[0] = 0;
        order[1] = 0;
        order[2] = 0;
        order[3] = 1;
        order[4] = 0;
        if (useReqisteredStandards) {
            solverIntent = _useRegisteredStandards(solverIntent);
        }
        return _solution(intent, solverIntent, order);
    }

    function _solutionForTokenSwapToErc20(
        UserIntent memory intent,
        uint256 erc20RequireAmount,
        bool useReqisteredStandards,
        bool isProxy
    ) private view returns (IntentSolution memory) {
        address forwardTo;
        if (isProxy) {
            forwardTo = address(_publicAddress);
        } else {
            forwardTo = address(_account);
        }
        bytes memory solve =
            _solverSwapETHForERC20AndForward(address(_publicAddressSolver), erc20RequireAmount, forwardTo);
        UserIntent memory solverIntent = _solverIntent();
        solverIntent = _addSimpleCall(solverIntent, solve);
        uint256[] memory order = new uint256[](5);
        order[0] = 0;
        order[1] = 0;
        order[2] = 0;
        order[3] = 1;
        order[4] = 0;
        if (useReqisteredStandards) {
            solverIntent = _useRegisteredStandards(solverIntent);
        }
        return _solution(intent, solverIntent, order);
    }
}
