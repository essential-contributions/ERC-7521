// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to buy an ERC1155 NFT using yet to claim aridropped ERC20 tokens
 * but they need native tokens to do the purchase.
 *
 * Intent Action Part1: user claims the ERC20 airdrop and releases some of them for the solver
 *
 * Solution Part1:
 * 1. the solver takes the users released ERC20s and swaps them all to wrappedETH
 * 2. all wrappedETH is unwrapped and enough ETH is forwarded to the user account to cover the purchase
 * 3. the solver buys the required ERC721 NFT and transfers it to the users account
 *
 * Intent Action Part2: user account makes the intended purchase with the newly received ETH
 *
 * Solution Part2:
 * 1. the solver sells the ERC721 NFT and moves all remaining ETH to their wallet
 */
contract GaslessAirdropConditionalPurchaseNFT is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    uint256 private _reqTokenId;

    function _intentForCase(uint256 claimAmount, uint256 totalAmountToSolver, uint256 nftPrice)
        private
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment(_accountClaimAirdropERC20(claimAmount)).releaseERC20(
                address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(int256(totalAmountToSolver))
            )
        );
        intent = intent.addSegment(
            _segment(_accountBuyERC1155AndTransferERC721(nftPrice, _reqTokenId, address(_assetBasedIntentStandard)))
        );
        intent = intent.addSegment(
            _segment("").requireETH(AssetBasedIntentCurveBuilder.constantCurve(0), false).requireERC721(
                address(_testERC721), _reqTokenId, AssetBasedIntentCurveBuilder.constantCurve(0), false
            )
        );
        return intent;
    }

    function _solverIntentForCase(uint256 totalAmountToSolver, uint256 nftPrice)
        private
        view
        returns (UserIntent memory)
    {
        return _solverIntent(
            _solverSwapAllERC20ForETHBuyNFTAndForward(totalAmountToSolver, nftPrice, nftPrice, address(_account)),
            _solverSellERC721AndForward(_reqTokenId, address(_publicAddressSolver)),
            "",
            2
        );
    }

    function setUp() public override {
        super.setUp();

        //determine required token
        _reqTokenId = _testERC721.nextNFTForSale();
    }

    // the max value uint72 can hold is just more than 1000 ether,
    // that is the amount of test tokens that were minted
    function testFuzz_gaslessAirdropConditionalPurchaseNFT(uint72 claimAmount, uint64 totalAmountToSolver) public {
        vm.assume(claimAmount < 1000 ether);
        vm.assume(totalAmountToSolver < claimAmount);
        uint256 nftPrice = _testERC1155.nftCost();
        vm.assume(2 * nftPrice <= totalAmountToSolver);

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, totalAmountToSolver, nftPrice);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(totalAmountToSolver, nftPrice);

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
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        // TODO: document the + 5
        assertEq(solverBalance, (totalAmountToSolver - nftPrice) + 5, "The solver ended up with incorrect balance");
        assertEq(
            userERC20Tokens, claimAmount - totalAmountToSolver, "The user released more ERC20 tokens than expected"
        );
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    function test_failGaslessAirdropConditionalPurchaseNFT_insufficientReleaseBalance() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 claimAmount = 100 ether;
        uint256 totalAmountToSolver = claimAmount + 1;

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, totalAmountToSolver, nftPrice);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(totalAmountToSolver, nftPrice);

        //create solution
        IntentSolution memory solution = _solution(intent, solverIntent);

        //execute
        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: insufficient release balance"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failGaslessAirdropConditionalPurchaseNFT_outOfFund() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 claimAmount = nftPrice - 1;
        uint256 totalAmountToSolver = claimAmount - 1;

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, totalAmountToSolver, nftPrice);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(totalAmountToSolver, nftPrice);

        //create solution
        IntentSolution memory solution = _solution(intent, solverIntent);

        //execute
        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 1, 0, "AA61 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failGaslessAirdropConditionalPurchaseNFT_wrongSignature() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 claimAmount = 100 ether;
        uint256 totalAmountToSolver = 2 * nftPrice;

        //create account intent
        UserIntent memory intent = _intentForCase(claimAmount, totalAmountToSolver, nftPrice);
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
