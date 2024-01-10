// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";
import "../../../src/standards/utils/CurveCoder.sol";

/*
 * In this scenario, a user is specifying different tokens to release and tokens expected by the end.
 *
 * Solution:
 * 1. the solver swaps the released tokens for the desired tokens and pockets the difference
 */
contract TokenSwaps is ScenarioTestEnvironment {
    uint256 private _accountInitialETHBalance = 100 ether;
    uint256 private _accountInitialERC20Balance = 100 ether;

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
        intent = _addEthRecord(intent);
        intent = _addErc20ReleaseLinear(
            intent,
            uint32(block.timestamp - releaseAt),
            uint24(releaseDuration),
            releaseStartAmount,
            (releaseEndAmount - releaseStartAmount) / int256(releaseDuration)
        );
        intent = _addEthRequire(intent, int256(ethRequireAmount), true);
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
        intent = _addEthRecord(intent);
        intent = _addErc20Release(intent, int256(erc20ReleaseAmount));
        intent = _addEthRequireLinear(
            intent,
            uint32(block.timestamp - requireAt),
            uint24(requireDuration),
            requireStartAmount,
            (requireEndAmount - requireStartAmount) / int256(requireDuration),
            true
        );
        return intent;
    }

    function _solutionForCase(UserIntent memory intent, uint256 erc20ReleaseAmount, uint256 ethRequireAmount)
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

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), _accountInitialERC20Balance);
        vm.deal(address(_account), _accountInitialETHBalance);

        //set block timestamp to something reasonable
        vm.warp(1700952587);
    }

    function testFuzz_constantRelease(uint32 erc20Release, uint32 ethRequire, uint16 requireDuration, uint16 requireAt)
        public
    {
        vm.assume(0 < erc20Release);
        vm.assume(0 < ethRequire);
        vm.assume(0 < requireDuration);
        vm.assume(0 < requireAt);
        vm.assume(requireAt < requireDuration);
        vm.assume(ethRequire < erc20Release);
        vm.assume(erc20Release < _accountInitialERC20Balance);
        uint256 erc20ReleaseAmount = uint256(erc20Release) * 1_000_000_000;
        uint256 ethRequireAmount = uint256(ethRequire) * 100_000_000;
        uint256 slippage = 5;

        //build intent
        UserIntent memory intent =
            _constantReleaseIntent(erc20ReleaseAmount, ethRequireAmount, requireDuration, requireAt);
        intent = _signIntent(intent);
        uint256 erc20ReleaseAmountEncoded =
            uint256(evaluateCurve(bytes16(_getBytes(intent.intentData[2], 64, 70)), block.timestamp));
        uint256 ethRequireAmountEncoded =
            uint256(evaluateCurve(bytes16(_getBytes(intent.intentData[3], 32, 48)), block.timestamp));

        //build solution
        IntentSolution memory solution = _solutionForCase(intent, erc20ReleaseAmountEncoded, ethRequireAmountEncoded);

        //execute
        _entryPoint.handleIntents(solution);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 expectedSolverBalance = (erc20ReleaseAmountEncoded - ethRequireAmountEncoded) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = _accountInitialETHBalance + ethRequireAmountEncoded;
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 expectedUserERC20Balance = _accountInitialERC20Balance - erc20ReleaseAmountEncoded;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
    }

    function testFuzz_constantExpectation(
        uint32 erc20Release,
        uint32 ethRequire,
        uint16 releaseDuration,
        uint16 releaseAt
    ) public {
        vm.assume(0 < erc20Release);
        vm.assume(0 < ethRequire);
        vm.assume(0 < releaseDuration);
        vm.assume(0 < releaseAt);
        vm.assume(releaseAt < releaseDuration);
        vm.assume(ethRequire < erc20Release);
        vm.assume(erc20Release < _accountInitialERC20Balance);
        uint256 slippage = 5;
        uint256 erc20ReleaseAmount = uint256(erc20Release) * 1_000_000_000;
        uint256 ethRequireAmount = uint256(ethRequire) * 100_000_000;

        //build intent
        UserIntent memory intent =
            _constantExpectationIntent(erc20ReleaseAmount, ethRequireAmount, releaseDuration, releaseAt);
        intent = _signIntent(intent);
        uint256 erc20ReleaseAmountEncoded =
            uint256(evaluateCurve(bytes16(_getBytes(intent.intentData[2], 64, 80)), block.timestamp));
        uint256 ethRequireAmountEncoded =
            uint256(evaluateCurve(bytes16(_getBytes(intent.intentData[3], 32, 38)), block.timestamp));

        //build solution
        IntentSolution memory solution = _solutionForCase(intent, erc20ReleaseAmountEncoded, ethRequireAmountEncoded);

        //execute
        _entryPoint.handleIntents(solution);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 expectedSolverBalance = (erc20ReleaseAmountEncoded - ethRequireAmountEncoded) + slippage;
        assertEq(solverBalance, expectedSolverBalance, "The solver ended up with incorrect balance");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = _accountInitialETHBalance + ethRequireAmountEncoded;
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect balance");

        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 expectedUserERC20Balance = _accountInitialERC20Balance - erc20ReleaseAmountEncoded;
        assertEq(userERC20Tokens, expectedUserERC20Balance, "The user released more ERC20 tokens than expected");
    }
}
