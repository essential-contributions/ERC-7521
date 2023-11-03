// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";
import {EthCurveLibHarness} from "../../../src/test/EthCurveLibHarness.sol";
import {EthCurve, evaluate} from "../../../src/utils/curves/EthCurve.sol";
import {generateFlags} from "../../../src/utils/Helpers.sol";
import {Erc20CurveLibHarness} from "../../../src/test/Erc20CurveLibHarness.sol";
import {Erc20Curve, CurveType, EvaluationType} from "../../../src/utils/curves/Erc20Curve.sol";

/*
 * In this scenario, a user is specifying different tokens to release and tokens expected by the end.
 *
 * Solution:
 * 1. the solver swaps the released tokens for the desired tokens and pockets the difference
 */
contract TokenSwaps is ScenarioTestEnvironment {
    using Erc20ReleaseIntentSegmentBuilder for Erc20ReleaseIntentSegment;
    using Erc20CurveLibHarness for Erc20Curve;
    using EthRequireIntentSegmentBuilder for EthRequireIntentSegment;
    using EthCurveLibHarness for EthCurve;

    uint256 private _accountInitialETHBalance = 100 ether;
    uint256 private _accountInitialERC20Balance = 100 ether;

    function _intentForCase(int256[] memory erc20ReleaseCurveParams, int256[] memory ethRequireCurveParams)
        private
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = _addErc20ReleaseSegment(intent, address(_testERC20), erc20ReleaseCurveParams);
        intent = _addEthRequireSegment(intent, ethRequireCurveParams, true);
        intent = _addSequentialNonceSegment(intent, 1);
        return intent;
    }

    function _constantReleaseSolution(UserIntent memory intent, uint256 erc20ReleaseAmount, uint256 evaluation)
        private
        view
        returns (IntentSolution memory)
    {
        UserIntent memory solverIntent = _solverIntent(
            _solverSwapERC20ForETHAndForward(
                erc20ReleaseAmount, address(_publicAddressSolver), evaluation, address(_account)
            ),
            "",
            "",
            1
        );
        return _solution(intent, solverIntent);
    }

    function _constantExpectationSolution(UserIntent memory intent, uint256 ethRequireAmount, uint256 evaluation)
        private
        view
        returns (IntentSolution memory)
    {
        UserIntent memory solverIntent = _solverIntent(
            _solverSwapERC20ForETHAndForward(
                evaluation, address(_publicAddressSolver), ethRequireAmount, address(_account)
            ),
            "",
            "",
            1
        );
        return _solution(intent, solverIntent);
    }

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), _accountInitialERC20Balance);
        vm.deal(address(_account), _accountInitialETHBalance);

        //set specific block.timestamp
        vm.warp(1000);
    }

    function testFuzz_constantRelease(
        uint72 erc20ReleaseAmount,
        int16 m,
        int72 b,
        uint16 max,
        bool flipY,
        uint16 timestamp
    ) public {
        vm.assume(0 < timestamp);
        vm.assume(0 < erc20ReleaseAmount);
        vm.assume(0 < max);
        vm.assume(0 < b);
        vm.assume(erc20ReleaseAmount < _accountInitialERC20Balance);

        //set specific block.timestamp
        vm.warp(timestamp);

        int256[] memory erc20ReleaseCurveParams = CurveBuilder.constantCurve(int256(uint256(erc20ReleaseAmount)));
        int256[] memory ethRequireCurveParams = CurveBuilder.linearCurve(m / int256(uint256(max)), b, max, flipY);

        EthCurve memory ethRequireCurve =
            EthCurve({flags: generateFlags(CurveType.LINEAR, EvaluationType.RELATIVE), params: ethRequireCurveParams});

        uint256 evaluation = uint256(ethRequireCurve.evaluateCurve(timestamp));

        vm.assume(evaluation < erc20ReleaseAmount);

        {
            UserIntent memory intent = _intentForCase(erc20ReleaseCurveParams, ethRequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IntentSolution memory solution = _constantReleaseSolution(intent, erc20ReleaseAmount, evaluation);

            //execute
            _entryPoint.handleIntents(solution);
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            // TODO: document the + 5
            uint256 expectedSolverBalance = erc20ReleaseAmount - evaluation + 5;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = _accountInitialETHBalance + evaluation;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance = _accountInitialERC20Balance - erc20ReleaseAmount;
            assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }

    function testFuzz_constantExpectation(
        uint72 ethRequireAmount,
        int16 m,
        int72 b,
        uint8 e,
        uint16 max,
        bool flipY,
        uint16 timestamp
    ) public {
        vm.assume(0 < timestamp);
        vm.assume(0 < ethRequireAmount);
        vm.assume(0 < max);
        vm.assume(0 < b);
        vm.assume(e < 16);
        vm.assume(ethRequireAmount < _accountInitialETHBalance);

        // set specific block.timestamp
        vm.warp(timestamp);

        Erc20Curve memory erc20ReleaseCurve;

        int256[] memory erc20ReleaseCurveParams = CurveBuilder.exponentialCurve(m, b, int256(uint256(e)), max, flipY);

        uint96 erc20ReleaseCurveFlags = generateFlags(CurveType.EXPONENTIAL, EvaluationType.RELATIVE);

        int256[] memory ethRequireCurveParams = CurveBuilder.constantCurve(int256(uint256(ethRequireAmount)));

        erc20ReleaseCurve = Erc20Curve({
            erc20Contract: address(_testERC20),
            flags: erc20ReleaseCurveFlags,
            params: erc20ReleaseCurveParams
        });

        uint256 evaluation = uint256(erc20ReleaseCurve.evaluateCurve(timestamp));
        vm.assume(ethRequireAmount < evaluation);
        vm.assume(evaluation < _accountInitialERC20Balance);

        {
            //create account intent (curve should evaluate as 7.75ether at timestamp 1000)
            UserIntent memory intent = _intentForCase(erc20ReleaseCurveParams, ethRequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IntentSolution memory solution = _constantExpectationSolution(intent, ethRequireAmount, evaluation);

            //execute
            _entryPoint.handleIntents(solution);
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            // TODO: document the + 5
            uint256 expectedSolverBalance = evaluation - ethRequireAmount + 5;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = _accountInitialETHBalance + ethRequireAmount;
            assertEq(userBalance, expectedUserBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 exptectedUserERC20Balance = _accountInitialERC20Balance - evaluation;
            assertEq(userERC20Tokens, exptectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }

    function test_failConstantRelease_insufficientReleaseBalance() public {
        uint256 erc20ReleaseAmount = _accountInitialERC20Balance + 1;
        uint16 timestamp = 1000;

        //set specific block.timestamp
        vm.warp(timestamp);

        int256[] memory erc20ReleaseCurveParams = CurveBuilder.constantCurve(int256(uint256(erc20ReleaseAmount)));
        int256[] memory ethRequireCurveParams = CurveBuilder.linearCurve(3 ether / 3000, 7 ether, 3000, false);

        EthCurve memory ethRequireCurve =
            EthCurve({flags: generateFlags(CurveType.LINEAR, EvaluationType.RELATIVE), params: ethRequireCurveParams});

        //create intent
        UserIntent memory intent = _intentForCase(erc20ReleaseCurveParams, ethRequireCurveParams);
        intent = _signIntent(intent);

        //create solution
        uint256 evaluation = uint256(ethRequireCurve.evaluateCurve(timestamp));
        IntentSolution memory solution = _constantReleaseSolution(intent, erc20ReleaseAmount, evaluation);

        //execute
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: insufficient release balance"
            )
        );
        _entryPoint.handleIntents(solution);
    }
}
