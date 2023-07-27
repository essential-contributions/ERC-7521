// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to buy an ERC1155 NFT but has to own a certain ERC721 NFT which 
 * neither the solver or user have or want by the end.
 *
 * Solution Part1:
 * 1. the solver buys the required ERC721 NFT and transfers it to the users account
 *
 * Intent Action: user account makes the intended purchase and transfers back the ERC721 NFT
 *
 * Solution Part2:
 * 1. the solver sells the ERC721 NFT and moves all remaining ETH to their wallet
 */
contract ConditionalPurchaseNFT is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    uint256 private _reqTokenId;

    function setUp() public override {
        super.setUp();

        //determine required token
        _reqTokenId = _testERC721.nextNFTForSale();

        //fund account
        vm.deal(address(_account), 10 ether);
    }

    function test_conditionalPurchaseNFT() public {
        //create account intent
        UserIntent memory userIntent = _intent();
        userIntent = userIntent.addSegment(_segment("").releaseETH(constantCurve(2 ether)));
        userIntent = userIntent.addSegment(
            _segment(_accountBuyERC1155AndTransferERC721(1 ether, _reqTokenId, address(_intentStandard)))
        );
        userIntent = userIntent.addSegment(
            _segment("").requireERC721(address(_testERC721), _reqTokenId, constantCurve(0), false)
        );
        userIntent = _signIntent(userIntent);

        //create solution
        IEntryPoint.SolutionStep[] memory steps1 = _solverBuyERC721AndForward(1 ether, address(_account));
        IEntryPoint.SolutionStep[] memory steps2 =
            _solverSellERC721AndForward(_reqTokenId, address(_publicAddressSolver));
        IEntryPoint.IntentSolution memory solution = _solution(userIntent, steps1, steps2, _noSteps());

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userBalance = address(_account).balance;
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(solverBalance, 2 ether, "The solver ended up with incorrect balance");
        assertEq(userBalance, 7 ether, "The user released more native tokens than expected");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    function test_failIntentSecondPass() public {
        bytes memory intentCallData1;
        // 101 ether is 1 ether more than what the account was funded
        bytes memory intentCallData2 =
            _accountBuyERC1155AndTransferERC721(101 ether, _reqTokenId, address(_intentStandard));

        UserIntent memory userIntent = _createIntent(intentCallData1, intentCallData2);
        userIntent = userIntent.addReleaseETH(constantCurve(2 ether));
        userIntent = userIntent.addRequiredERC721(address(_testERC721), _reqTokenId, constantCurve(0), false);
        userIntent = _signIntent(userIntent);

        IEntryPoint.SolutionStep[] memory steps1 = _solverBuyERC721AndForward(1 ether, address(_account));
        IEntryPoint.SolutionStep[] memory steps2 =
            _solverSellERC721AndForward(_reqTokenId, address(_publicAddressSolver));

        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, "AA63 second pass reverted (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }

    // function test_failSolutionSecondPass() public {
    //     bytes memory intentCallData1;
    //     bytes memory intentCallData2 =
    //         _accountBuyERC1155AndTransferERC721(1 ether, _reqTokenId, address(_intentStandard));

    //     UserIntent memory userIntent = _createIntent(intentCallData1, intentCallData2);
    //     userIntent = userIntent.addReleaseETH(constantCurve(2 ether));
    //     userIntent = userIntent.addRequiredERC721(address(_testERC721), _reqTokenId, constantCurve(0), false);
    //     userIntent = _signIntent(userIntent);

    //     IEntryPoint.SolutionStep[] memory steps1 = _solverBuyERC721AndForward(1 ether, address(_account));
    //     // invalid token ID
    //     IEntryPoint.SolutionStep[] memory steps2 =
    //         _solverSellERC721AndForward(_reqTokenId - 1, address(_publicAddressSolver));

    //     IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

    //     // TODO: investigate why the caught revert is slightly different
    //     vm.expectRevert(
    //         abi.encodeWithSelector(IEntryPoint.FailedSolution.selector, 0, "AA72 second pass reverted: Invalid ID")
    //     );
    //     _entryPoint.handleIntents(solution);
    // }

    //TODO: clone the success scenario and tweak it to verify correct failures (ex. signature validation)
}
