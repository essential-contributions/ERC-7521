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

    function _constantReleaseIntent(int256[] memory ERC20ReleaseCurveParams, int256[] memory ETHRequireCurveParams)
        internal
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(_segment("").releaseERC20(address(_testERC20), ERC20ReleaseCurveParams));
        intent = intent.addSegment(_segment("").requireETH(ETHRequireCurveParams, true));
        return intent;
    }

    function _constantReleaseSolution(UserIntent memory intent, uint256 ERC20ReleaseAmount, uint256 evaluation)
        internal
        view
        returns (IEntryPoint.IntentSolution memory)
    {
        bytes[] memory steps1 = _solverSwapAllERC20ForETHAndForward(
            ERC20ReleaseAmount, address(_publicAddressSolver), evaluation, address(_account)
        );
        return _solution(_singleIntent(intent), steps1, _noSteps(), _noSteps());
    }

    function _constantExpectationIntent(int256[] memory ERC20ReleaseCurveParams, int256[] memory ETHRequireCurveParams)
        internal
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(_segment("").releaseERC20(address(_testERC20), ERC20ReleaseCurveParams));
        intent = intent.addSegment(_segment("").requireETH(ETHRequireCurveParams, true));
        return intent;
    }

    function _constantExpectationSolution(UserIntent memory intent, uint256 ETHRequireAmount, uint256 evaluation)
        internal
        view
        returns (IEntryPoint.IntentSolution memory)
    {
        bytes[] memory steps1 = _solverSwapAllERC20ForETHAndForward(
            evaluation, address(_publicAddressSolver), ETHRequireAmount, address(_account)
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
        uint72 ERC20ReleaseAmount,
        int16 m,
        int72 b,
        uint16 max,
        bool flipY,
        uint16 timestamp
    ) public {
        vm.assume(0 < ERC20ReleaseAmount);
        vm.assume(0 < max);
        vm.assume(0 < b);
        vm.assume(ERC20ReleaseAmount < accountInitialERC20Balance);

        //set specific block.timestamp
        vm.warp(timestamp);

        int256[] memory ERC20ReleaseCurveParams =
            AssetBasedIntentCurveBuilder.constantCurve(int256(uint256(ERC20ReleaseAmount)));
        int256[] memory ETHRequireCurveParams =
            AssetBasedIntentCurveBuilder.linearCurve(m / int256(uint256(max)), b, max, flipY);

        AssetBasedIntentCurve memory ETHRequireCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            flags: AssetBasedIntentCurveLib.generateFlags(AssetType.ETH, CurveType.LINEAR, EvaluationType.RELATIVE),
            params: ETHRequireCurveParams
        });

        uint256 evaluation = uint256(ETHRequireCurve.evaluate(timestamp));

        vm.assume(evaluation < ERC20ReleaseAmount);

        {
            UserIntent memory intent = _constantReleaseIntent(ERC20ReleaseCurveParams, ETHRequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IEntryPoint.IntentSolution memory solution =
                _constantReleaseSolution(intent, ERC20ReleaseAmount, evaluation);

            //simulate execution
            vm.expectRevert(abi.encodeWithSelector(IEntryPoint.ExecutionResult.selector, true, false, ""));
            _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");

            //execute
            uint256 gasBefore = gasleft();
            _entryPoint.handleIntents(solution);
            console.log("Gas Consumed: %d", gasBefore - gasleft());
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            // TODO: document the + 5
            uint256 expectedSolverBalance = ERC20ReleaseAmount - evaluation + 5;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = accountInitialETHBalance + evaluation;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 expectedUserERC20Balance = accountInitialERC20Balance - ERC20ReleaseAmount;
            assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }

    function testFuzz_constantExpectation(
        uint72 ETHRequireAmount,
        int16 m,
        int72 b,
        uint8 e,
        uint16 max,
        bool flipY,
        uint16 timestamp
    ) public {
        vm.assume(0 < ETHRequireAmount);
        vm.assume(0 < max);
        vm.assume(0 < b);
        vm.assume(e < 16);
        vm.assume(ETHRequireAmount < accountInitialETHBalance);

        // set specific block.timestamp
        vm.warp(timestamp);

        AssetBasedIntentCurve memory ERC20ReleaseCurve;

        int256[] memory ERC20ReleaseCurveParams =
            AssetBasedIntentCurveBuilder.exponentialCurve(m, b, int256(uint256(e)), max, flipY);

        uint96 ERC20ReleaseCurveFlags =
            AssetBasedIntentCurveLib.generateFlags(AssetType.ERC20, CurveType.EXPONENTIAL, EvaluationType.RELATIVE);

        int256[] memory ETHRequireCurveParams =
            AssetBasedIntentCurveBuilder.constantCurve(int256(uint256(ETHRequireAmount)));

        ERC20ReleaseCurve = AssetBasedIntentCurve({
            assetContract: address(_testERC20),
            assetId: 0,
            flags: ERC20ReleaseCurveFlags,
            params: ERC20ReleaseCurveParams
        });

        uint256 evaluation = uint256(ERC20ReleaseCurve.evaluate(timestamp));
        vm.assume(ETHRequireAmount < evaluation);
        vm.assume(evaluation < accountInitialERC20Balance);

        {
            //create account intent (curve should evaluate as 7.75ether at timestamp 1000)
            UserIntent memory intent = _constantExpectationIntent(ERC20ReleaseCurveParams, ETHRequireCurveParams);
            intent = _signIntent(intent);

            //create solution
            IEntryPoint.IntentSolution memory solution =
                _constantExpectationSolution(intent, ETHRequireAmount, evaluation);

            //simulate execution
            vm.expectRevert(abi.encodeWithSelector(IEntryPoint.ExecutionResult.selector, true, false, ""));
            _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");

            //execute
            uint256 gasBefore = gasleft();
            _entryPoint.handleIntents(solution);
            console.log("Gas Consumed: %d", gasBefore - gasleft());
        }

        //verify end state
        {
            uint256 solverBalance = address(_publicAddressSolver).balance;
            // TODO: document the + 5
            uint256 expectedSolverBalance = evaluation - ETHRequireAmount + 5;
            assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = accountInitialETHBalance + ETHRequireAmount;
            assertEq(userBalance, expectedUserBalance, "The solver ended up with incorrect balance");
        }
        {
            uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
            uint256 exptectedUserERC20Balance = accountInitialERC20Balance - evaluation;
            assertEq(userERC20Tokens, exptectedUserERC20Balance, "The user released more ERC20 tokens than expected");
        }
    }

    function test_failConstantRelease_insufficientReleaseBalance() public {
        uint256 ERC20ReleaseAmount = accountInitialERC20Balance + 1;
        uint16 timestamp = 1000;

        //set specific block.timestamp
        vm.warp(timestamp);

        int256[] memory ERC20ReleaseCurveParams =
            AssetBasedIntentCurveBuilder.constantCurve(int256(uint256(ERC20ReleaseAmount)));
        int256[] memory ETHRequireCurveParams =
            AssetBasedIntentCurveBuilder.linearCurve(3 ether / 3000, 7 ether, 3000, false);

        AssetBasedIntentCurve memory ETHRequireCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            flags: AssetBasedIntentCurveLib.generateFlags(AssetType.ETH, CurveType.LINEAR, EvaluationType.RELATIVE),
            params: ETHRequireCurveParams
        });

        //create intent
        UserIntent memory intent = _constantReleaseIntent(ERC20ReleaseCurveParams, ETHRequireCurveParams);
        intent = _signIntent(intent);

        //create solution
        uint256 evaluation = uint256(ETHRequireCurve.evaluate(timestamp));
        IEntryPoint.IntentSolution memory solution = _constantReleaseSolution(intent, ERC20ReleaseAmount, evaluation);

        //execute
        // TODO: https://github.com/essential-contributions/galactus/issues/50
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: __insufficient release balance__"
            )
        );
        _entryPoint.handleIntents(solution);
    }
}
