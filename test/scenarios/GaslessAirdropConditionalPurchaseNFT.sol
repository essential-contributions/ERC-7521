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

    function setUp() public override {
        super.setUp();

        //determine required token
        _reqTokenId = _testERC721.nextNFTForSale();
    }

    function test_gaslessAirdropConditionalPurchaseNFT() public {
        //create account intent
        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment(_accountClaimAirdropERC20(100 ether)).releaseERC20(
                address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(2 ether)
            )
        );
        intent = intent.addSegment(
            _segment(_accountBuyERC1155AndTransferERC721(1 ether, _reqTokenId, address(_intentStandard)))
        );
        intent = intent.addSegment(
            _segment("").requireETH(AssetBasedIntentCurveBuilder.constantCurve(0), false).requireERC721(
                address(_testERC721), _reqTokenId, AssetBasedIntentCurveBuilder.constantCurve(0), false
            )
        );
        intent = _signIntent(intent);

        //create solution
        bytes[] memory steps1 = _combineSolutionSteps(
            _solverSwapAllERC20ForETHAndForward(2 ether, address(_intentStandard), 1 ether, address(_account)),
            _solverBuyERC721AndForward(1 ether, address(_account))
        );
        bytes[] memory steps2 = _solverSellERC721AndForward(_reqTokenId, address(_publicAddressSolver));
        IEntryPoint.IntentSolution memory solution = _solution(intent, steps1, steps2, _noSteps());

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(solverBalance, (1 ether) + 5, "The solver ended up with incorrect balance");
        assertEq(userERC20Tokens, 98 ether, "The user released more ERC20 tokens than expected");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
