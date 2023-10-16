// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to claim airdropped ERC20 tokens but wants to pay for gas
 * with some of the tokens they just received.
 *
 * Intent Action: user claims the ERC20 airdrop and releases some of them for the solver
 *
 * Solution:
 * 1. the solver takes the users released ERC20s and swaps them all to wrappedETH
 * 2. the solver unwraps all to ETH and moves them to their own wallet
 */
contract GaslessAirdrop is ScenarioTestEnvironment {
    using Erc20ReleaseIntentSegmentBuilder for Erc20ReleaseIntentSegment;

    function _intentForCase(uint256 claimAmount, uint256 gasPayment) private view returns (UserIntent memory) {
        UserIntent memory intent = _intent();
        intent = _addCallSegment(intent, CallIntentSegmentBuilder.create(_accountClaimAirdropERC20(claimAmount)));
        intent = _addErc20ReleaseSegment(
            intent,
            Erc20ReleaseIntentSegmentBuilder.create().releaseERC20(
                address(_testERC20), CurveBuilder.constantCurve(int256(gasPayment))
            )
        );
        return intent;
    }

    function _solverIntentForCase(uint256 gasPayment) private view returns (UserIntent memory) {
        return _solverIntent(_solverSwapAllERC20ForETH(gasPayment, address(_publicAddressSolver)), "", "", 1);
    }

    // the max value uint72 can hold is just more than 1000 ether,
    // that is the amount of test tokens that were minted
    function testFuzz_gaslessAirdrop(uint72 claimAmount, uint72 gasPayment) public {
        vm.assume(gasPayment < claimAmount);
        vm.assume(claimAmount < 1000 ether);

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, gasPayment);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(gasPayment);

        //create solution
        IntentSolution memory solution = _solution(intent, solverIntent);

        //simulate execution
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.ExecutionResult.selector, true, false, ""));
        _entryPoint.simulateHandleIntents(solution, address(0), "");

        //execute
        _entryPoint.handleIntents(solution);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        // TODO: document the + 5
        assertEq(solverBalance, gasPayment + 5, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, claimAmount - gasPayment, "The user released more ERC20 tokens than expected");
    }

    function test_failGaslessAirdrop_insufficientReleaseBalance() public {
        uint256 claimAmount = 100 ether;
        uint256 gasPayment = claimAmount + 1;

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, gasPayment);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(gasPayment);

        //create solution
        IntentSolution memory solution = _solution(intent, solverIntent);

        //execute
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 1, "AA61 execution failed: insufficient release balance"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failGaslessAirdrop_wrongSignature() public {
        uint256 claimAmount = 100 ether;
        uint256 gasPayment = 1 ether;

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, gasPayment);
        //sign with wrong key
        intent = _signIntentWithWrongKey(intent);

        // sigFailed == true for failing validation
        uint256 validationData = _packValidationData(true, uint48(intent.timestamp), 0);
        ValidationData memory valData = _parseValidationData(validationData);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.ValidationResult.selector, valData.sigFailed, valData.validAfter, valData.validUntil
            )
        );
        _entryPoint.simulateValidation(intent);
    }
}
