// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to buy an ERC1155 NFT using their ERC20 tokens but they need 
 * native tokens to do so.
 *
 * Solution:
 * 1. the solver takes the users released ERC20s and swaps them all to wrappedETH
 * 2. all wrappedETH is unwrapped and enough ETH is forwarded to the user account to cover the purchase
 * 3. the solver takes the remaining ETH
 *
 * Intent Action: user account makes the intended purchase with the newly received ETH
 */
contract PurchaseNFT is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    uint256 accountInitialERC20Balance = 1000 ether;

    function _intentForCase(uint256 totalAmountToSolver, uint256 nftPrice) internal view returns (UserIntent memory) {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment("").releaseERC20(
                address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(int256(totalAmountToSolver))
            )
        );
        intent = intent.addSegment(_segment(_accountBuyERC1155(nftPrice)));
        intent = intent.addSegment(_segment("").requireETH(AssetBasedIntentCurveBuilder.constantCurve(0), false));
        return intent;
    }

    function _solutionForCase(UserIntent memory intent, uint256 totalAmountToSolver, uint256 nftPrice)
        internal
        view
        returns (IEntryPoint.IntentSolution memory)
    {
        bytes[] memory steps1 = _solverSwapAllERC20ForETHAndForward(
            totalAmountToSolver, address(_publicAddressSolver), nftPrice, address(_account)
        );
        return _solution(_singleIntent(intent), steps1, _noSteps(), _noSteps());
    }

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), accountInitialERC20Balance);
    }

    function testFuzz_purchaseNFT(uint64 totalAmountToSolver) public {
        uint256 nftPrice = _testERC1155.nftCost();
        vm.assume(nftPrice < totalAmountToSolver);

        //create account intent
        UserIntent memory intent = _intentForCase(totalAmountToSolver, nftPrice);
        intent = _signIntent(intent);

        //create solution
        IEntryPoint.IntentSolution memory solution = _solutionForCase(intent, totalAmountToSolver, nftPrice);

        //simulate execution
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.ExecutionResult.selector, true, false, ""));
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        // TODO: document the + 5
        assertEq(solverBalance, (totalAmountToSolver - nftPrice) + 5, "The solver ended up with incorrect balance");
        assertEq(
            userERC20Tokens,
            accountInitialERC20Balance - totalAmountToSolver,
            "The user released more ERC20 tokens than expected"
        );
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    function test_failPurchaseNFT_insufficientReleaseBalance() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 totalAmountToSolver = accountInitialERC20Balance + 1;

        //create account intent
        UserIntent memory intent = _intentForCase(totalAmountToSolver, nftPrice);
        intent = _signIntent(intent);

        //create solution
        IEntryPoint.IntentSolution memory solution = _solutionForCase(intent, totalAmountToSolver, nftPrice);

        //execute
        // TODO: https://github.com/essential-contributions/galactus/issues/50
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: __insufficient release balance__"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failPurchaseNFT_outOfFund() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 totalAmountToSolver = 0;

        //create account intent
        UserIntent memory intent = _intentForCase(totalAmountToSolver, nftPrice);
        intent = _signIntent(intent);

        //create solution
        IEntryPoint.IntentSolution memory solution = _solutionForCase(intent, totalAmountToSolver, nftPrice);

        //execute
        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedSolution.selector, 1, "AA72 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failPurchaseNFT_wrongSignature() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 totalAmountToSolver = 2 ether;

        //create account intent
        UserIntent memory intent = _intentForCase(totalAmountToSolver, nftPrice);
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
