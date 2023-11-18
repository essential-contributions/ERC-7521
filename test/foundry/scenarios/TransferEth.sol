// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";
import {EthCurveLibHarness} from "../utils/harness/EthCurveLibHarness.sol";
import {EthCurve, evaluate} from "../../../src/utils/curves/EthCurve.sol";
import {Erc20CurveLibHarness} from "../utils/harness/Erc20CurveLibHarness.sol";
import {Erc20Curve, CurveType, EvaluationType} from "../../../src/utils/curves/Erc20Curve.sol";
import {generateFlags} from "../../../src/utils/Helpers.sol";

contract TransferEth is ScenarioTestEnvironment {
    using Erc20ReleaseIntentSegmentBuilder for Erc20ReleaseIntentSegment;
    using Erc20CurveLibHarness for Erc20Curve;
    using EthRequireIntentSegmentBuilder for EthRequireIntentSegment;
    using EthCurveLibHarness for EthCurve;

    uint256 private _accountInitialETHBalance = 0.1 ether;
    uint256 private _accountInitialERC20Balance = 0.01 ether;

    function _intentForCase(int256[] memory erc20ReleaseCurveParams, int256[] memory ethTransferCurveParams)
        private
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = _addErc20ReleaseSegment(intent, address(_testERC20), erc20ReleaseCurveParams);
        intent = _addEthReleaseSegment(intent, ethTransferCurveParams);
        intent = _addEthRequireSegment(intent, CurveBuilder.constantCurve(int256(0)), false);
        intent = _addSequentialNonceSegment(intent, 1);
        return intent;
    }

    function _solutionForCase(
        UserIntent memory intent,
        uint256 erc20ReleaseAmount,
        uint256 ethTransferAmount,
        address ethTransferTo
    ) private view returns (IntentSolution memory) {
        UserIntent memory solverIntent = _solverIntent(
            _solverSwapERC20ForETH(erc20ReleaseAmount, address(_publicAddressSolver)),
            _solverTransferETH(ethTransferTo, ethTransferAmount),
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

        //set specific block.timestamp
        vm.warp(1000);
    }

    function test_transferETH() public {
        uint256 timestamp = 1000;

        uint256 ethTransferAmount = 0.1 ether;
        int256[] memory ethTransferCurveParams = CurveBuilder.constantCurve(int256(ethTransferAmount));

        int256[] memory erc20ReleaseCurveParams =
            CurveBuilder.linearCurve(int256(_accountInitialERC20Balance) / 3000, 0, 3000, false);
        EthCurve memory erc20ReleaseCurve = EthCurve({
            timestamp: 0,
            flags: generateFlags(CurveType.LINEAR, EvaluationType.ABSOLUTE),
            params: erc20ReleaseCurveParams
        });
        uint256 erc20ReleaseEvaluation = uint256(erc20ReleaseCurve.evaluateCurve(timestamp));

        {
            UserIntent memory intent = _intentForCase(erc20ReleaseCurveParams, ethTransferCurveParams);
            intent = _signIntent(intent);

            //create solution
            IntentSolution memory solution =
                _solutionForCase(intent, erc20ReleaseEvaluation, ethTransferAmount, address(_publicAddress));

            //execute
            _entryPoint.handleIntents(solution);
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            uint256 expectedSolverBalance = erc20ReleaseEvaluation + 5;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = _accountInitialETHBalance - ethTransferAmount;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance = _accountInitialERC20Balance - erc20ReleaseEvaluation;
            assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
        {
            uint256 recipientBalance = address(_publicAddress).balance;
            uint256 expectedRecipientBalance = ethTransferAmount;
            assertEq(recipientBalance, expectedRecipientBalance, "The recipient ended up with incorrect balance");
        }
    }
}
