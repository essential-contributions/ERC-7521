// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

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

    uint256 internal _reqTokenId;

    uint256 accountInitialEthBalance = 10 ether;

    function _intentForCase(uint256 ethReleaseAmount, uint256 nftPrice) internal view returns (UserIntent memory) {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _segment("").releaseETH(AssetBasedIntentCurveBuilder.constantCurve(int256(ethReleaseAmount)))
        );
        intent = intent.addSegment(
            _segment(_accountBuyERC1155AndTransferERC721(nftPrice, _reqTokenId, address(_intentStandard)))
        );
        intent = intent.addSegment(
            _segment("").requireERC721(
                address(_testERC721), _reqTokenId, AssetBasedIntentCurveBuilder.constantCurve(0), false
            )
        );
        return intent;
    }

    function _solutionForCase(UserIntent memory intent, uint256 nftPrice)
        internal
        view
        returns (IEntryPoint.IntentSolution memory)
    {
        bytes[] memory steps1 = _solverBuyERC721AndForward(nftPrice, address(_account));
        bytes[] memory steps2 = _solverSellERC721AndForward(_reqTokenId, address(_publicAddressSolver));
        return _solution(_singleIntent(intent), steps1, steps2, _noSteps());
    }

    function setUp() public override {
        super.setUp();

        //determine required token
        _reqTokenId = _testERC721.nextNFTForSale();

        //fund account
        vm.deal(address(_account), accountInitialEthBalance);
    }

    // the max value uint64 can hold is just more than 10 ether,
    // that is the account's initial balance
    function testFuzz_conditionalPurchaseNFT(uint64 ethReleaseAmount) public {
        vm.assume(ethReleaseAmount < accountInitialEthBalance - _testERC1155.nftCost());
        uint256 nftPrice = _testERC1155.nftCost();
        vm.assume(nftPrice < ethReleaseAmount);

        //create account intent
        UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
        intent = _signIntent(intent);

        //create solution
        IEntryPoint.IntentSolution memory solution = _solutionForCase(intent, nftPrice);

        //simulate execution
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.ExecutionResult.selector, true, false, ""));
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userBalance = address(_account).balance;
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(solverBalance, ethReleaseAmount, "The solver ended up with incorrect balance");
        assertEq(
            userBalance,
            accountInitialEthBalance - (ethReleaseAmount + nftPrice),
            "The user released more native tokens than expected"
        );
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    // function test_failConditionalPurchaseNFT_insufficientReleaseBalance() public {
    //     uint256 nftPrice = _testERC1155.nftCost();
    //     uint256 ethReleaseAmount = accountInitialEthBalance + 1;

    //     //create account intent
    //     UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
    //     intent = _signIntent(intent);

    //     //create solution
    //     IEntryPoint.IntentSolution memory solution = _solutionForCase(intent, nftPrice);

    //     // TODO: string length expected 0x37, actual 0x33
    //     //execute
    //     vm.expectRevert(abi.encodeWithSelector(
    //         IEntryPoint.FailedIntent.selector, 0, 0, string.concat("AA61 execution failed: ", "insufficient release balance")
    //     ));
    //     _entryPoint.handleIntents(solution);
    // }

    function test_failConditionalPurchaseNFT_outOfFund() public {
        uint256 ethReleaseAmount = 2 ether;
        uint256 nftPrice = _testERC1155.nftCost();

        //create account intent
        UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
        intent = _signIntent(intent);

        //create solution
        //attempt to buy nft with insufficient funds
        IEntryPoint.IntentSolution memory solution = _solutionForCase(intent, accountInitialEthBalance + 1);

        bytes memory encoded =
            abi.encodeWithSelector(IEntryPoint.FailedSolution.selector, 0, "AA72 execution failed (or OOG)");

        //execute
        vm.expectRevert(encoded);
        _entryPoint.handleIntents(solution);
    }
}
