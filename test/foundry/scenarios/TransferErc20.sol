// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";
import {EthCurveLibHarness} from "../utils/harness/EthCurveLibHarness.sol";
import {EthCurve, evaluate} from "../../../src/utils/curves/EthCurve.sol";
import {Erc20CurveLibHarness} from "../utils/harness/Erc20CurveLibHarness.sol";
import {Erc20Curve, CurveType, EvaluationType} from "../../../src/utils/curves/Erc20Curve.sol";
import {generateFlags} from "../../../src/utils/Helpers.sol";

contract TransferErc20 is ScenarioTestEnvironment {
    using Erc20ReleaseIntentSegmentBuilder for Erc20ReleaseIntentSegment;
    using Erc20CurveLibHarness for Erc20Curve;
    using EthRequireIntentSegmentBuilder for EthRequireIntentSegment;
    using EthCurveLibHarness for EthCurve;

    uint256 private _accountInitialERC20Balance = 0.11 ether;

    function _intentForCase(
        int256[] memory erc20ReleaseCurveParams,
        int256[] memory erc20TransferCurveParams,
        int256[] memory erc20RequireCurveParams
    ) private view returns (UserIntent memory) {
        UserIntent memory intent = _intent();
        intent = _addErc20ReleaseSegment(intent, address(_testERC20), erc20ReleaseCurveParams);
        intent = _addErc20ReleaseSegment(intent, address(_testERC20), erc20TransferCurveParams);
        intent = _addErc20RequireSegment(intent, address(_testERC20), erc20RequireCurveParams, false);
        intent = _addSequentialNonceSegment(intent, 1);
        return intent;
    }

    function _solutionForCase(
        UserIntent memory intent,
        uint256 erc20ReleaseAmount,
        uint256 erc20transferAmount,
        address erc20transferTo
    ) private view returns (IntentSolution memory) {
        UserIntent memory solverIntent = _solverIntent(
            _solverSwapERC20ForETH(erc20ReleaseAmount, address(_publicAddressSolver)),
            _solverTransferERC20(erc20transferTo, erc20transferAmount),
            "",
            2
        );
        return _solution(intent, solverIntent);
    }

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), _accountInitialERC20Balance);

        //set specific block.timestamp
        vm.warp(1000);
    }

    function test_transferERC20() public {
        uint256 timestamp = 1000;

        uint256 erc20TransferAmount = 0.1 ether;
        int256[] memory erc20TransferCurveParams = CurveBuilder.constantCurve(int256(erc20TransferAmount));

        int256[] memory erc20ReleaseCurveParams =
            CurveBuilder.linearCurve(int256(_accountInitialERC20Balance - erc20TransferAmount) / 3000, 0, 3000, false);
        EthCurve memory erc20ReleaseCurve = EthCurve({
            timestamp: 0,
            flags: generateFlags(CurveType.LINEAR, EvaluationType.ABSOLUTE),
            params: erc20ReleaseCurveParams
        });
        uint256 erc20ReleaseEvaluation = uint256(erc20ReleaseCurve.evaluateCurve(timestamp));

        int256[] memory erc20RequireCurveParams =
            CurveBuilder.linearCurve(int256(_accountInitialERC20Balance - erc20TransferAmount) / 3000, 0, 3000, true);

        {
            UserIntent memory intent =
                _intentForCase(erc20ReleaseCurveParams, erc20TransferCurveParams, erc20RequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IntentSolution memory solution =
                _solutionForCase(intent, erc20ReleaseEvaluation, erc20TransferAmount, address(_publicAddress));

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
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance =
                _accountInitialERC20Balance - erc20TransferAmount - erc20ReleaseEvaluation;
            assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
        {
            uint256 recipientERC20Balance = _testERC20.balanceOf(address(_publicAddress));
            uint256 expectedRecipientERC20Balance = erc20TransferAmount;
            assertEq(
                recipientERC20Balance,
                expectedRecipientERC20Balance,
                "The recipient received less ERC20 tokens than expected"
            );
        }
    }
}
