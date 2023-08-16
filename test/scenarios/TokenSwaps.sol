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
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;

    uint256 accountInitialETHBalance = 100 ether;
    uint256 accountInitialERC20Balance = 100 ether;

    function _constantReleaseIntent(int256[] memory erc20ReleaseCurveParams, int256[] memory ethRequireCurveParams)
        internal
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(_segment("").releaseERC20(address(_testERC20), erc20ReleaseCurveParams));
        intent = intent.addSegment(_segment("").requireETH(ethRequireCurveParams, true));
        return intent;
    }

    function _constantReleaseSolution(UserIntent memory intent, uint256 erc20ReleaseAmount, uint256 evaluation)
        internal
        view
        returns (IEntryPoint.IntentSolution memory)
    {
        bytes[] memory steps1 = _solverSwapAllERC20ForETHAndForward(
            erc20ReleaseAmount, address(_publicAddressSolver), evaluation, address(_account)
        );
        return _solution(_singleIntent(intent), steps1, _noSteps(), _noSteps());
    }

    function _constantExpectationIntent(int256[] memory erc20ReleaseCurveParams, int256[] memory ethRequireCurveParams)
        internal
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(_segment("").releaseERC20(address(_testERC20), erc20ReleaseCurveParams));
        intent = intent.addSegment(_segment("").requireETH(ethRequireCurveParams, true));
        return intent;
    }

    function _constantExpectationSolution(UserIntent memory intent, uint256 ethRequireAmount, uint256 evaluation)
        internal
        view
        returns (IEntryPoint.IntentSolution memory)
    {
        bytes[] memory steps1 = _solverSwapAllERC20ForETHAndForward(
            evaluation, address(_publicAddressSolver), ethRequireAmount, address(_account)
        );
        return _solution(_singleIntent(intent), steps1, _noSteps(), _noSteps());
    }

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), accountInitialERC20Balance);
        vm.deal(address(_account), accountInitialETHBalance);

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
        vm.assume(0 < erc20ReleaseAmount);
        vm.assume(0 < max);
        vm.assume(0 < b);
        vm.assume(erc20ReleaseAmount < accountInitialERC20Balance);

        //set specific block.timestamp
        vm.warp(timestamp);

        int256[] memory erc20ReleaseCurveParams =
            AssetBasedIntentCurveBuilder.constantCurve(int256(uint256(erc20ReleaseAmount)));
        int256[] memory ethRequireCurveParams =
            AssetBasedIntentCurveBuilder.linearCurve(m / int256(uint256(max)), b, max, flipY);

        AssetBasedIntentCurve memory ethRequireCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            flags: AssetBasedIntentCurveLib.generateFlags(AssetType.ETH, CurveType.LINEAR, EvaluationType.RELATIVE),
            params: ethRequireCurveParams
        });

        uint256 evaluation = uint256(ethRequireCurve.evaluate(timestamp));

        vm.assume(evaluation < erc20ReleaseAmount);

        {
            UserIntent memory intent = _constantReleaseIntent(erc20ReleaseCurveParams, ethRequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IEntryPoint.IntentSolution memory solution =
                _constantReleaseSolution(intent, erc20ReleaseAmount, evaluation);

            //execute
            uint256 gasBefore = gasleft();
            _entryPoint.handleIntents(solution);
            console.log("Gas Consumed: %d", gasBefore - gasleft());
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
            uint256 expectedUserBalance = accountInitialETHBalance + evaluation;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance = accountInitialERC20Balance - erc20ReleaseAmount;
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
        vm.assume(0 < ethRequireAmount);
        vm.assume(0 < max);
        vm.assume(0 < b);
        vm.assume(e < 16);
        vm.assume(ethRequireAmount < accountInitialETHBalance);

        // set specific block.timestamp
        vm.warp(timestamp);

        AssetBasedIntentCurve memory erc20ReleaseCurve;

        int256[] memory erc20ReleaseCurveParams =
            AssetBasedIntentCurveBuilder.exponentialCurve(m, b, int256(uint256(e)), max, flipY);

        uint96 erc20ReleaseCurveFlags =
            AssetBasedIntentCurveLib.generateFlags(AssetType.ERC20, CurveType.EXPONENTIAL, EvaluationType.RELATIVE);

        int256[] memory ethRequireCurveParams =
            AssetBasedIntentCurveBuilder.constantCurve(int256(uint256(ethRequireAmount)));

        erc20ReleaseCurve = AssetBasedIntentCurve({
            assetContract: address(_testERC20),
            assetId: 0,
            flags: erc20ReleaseCurveFlags,
            params: erc20ReleaseCurveParams
        });

        uint256 evaluation = uint256(erc20ReleaseCurve.evaluate(timestamp));
        vm.assume(ethRequireAmount < evaluation);
        vm.assume(evaluation < accountInitialERC20Balance);

        {
            //create account intent (curve should evaluate as 7.75ether at timestamp 1000)
            UserIntent memory intent = _constantExpectationIntent(erc20ReleaseCurveParams, ethRequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IEntryPoint.IntentSolution memory solution =
                _constantExpectationSolution(intent, ethRequireAmount, evaluation);

            //execute
            uint256 gasBefore = gasleft();
            _entryPoint.handleIntents(solution);
            console.log("Gas Consumed: %d", gasBefore - gasleft());
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
            uint256 expectedUserBalance = accountInitialETHBalance + ethRequireAmount;
            assertEq(userBalance, expectedUserBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 exptectedUserERC20Balance = accountInitialERC20Balance - evaluation;
            assertEq(userERC20Tokens, exptectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
