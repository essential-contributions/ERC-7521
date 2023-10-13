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
    using EthReleaseIntentSegmentBuilder for EthReleaseIntentSegment;
    using AssetRequireIntentSegmentBuilder for AssetRequireIntentSegment;

    uint256 private _reqTokenId;
    uint256 private _accountInitialETHBalance = 10 ether;

    function _intentForCase(uint256 ethReleaseAmount, uint256 nftPrice) private view returns (UserIntent memory) {
        UserIntent memory intent = _intent();
        intent = _addEthReleaseSegment(
            intent,
            EthReleaseIntentSegmentBuilder.create().releaseETH(
                EthReleaseIntentCurveBuilder.constantCurve(int256(ethReleaseAmount))
            )
        );
        intent = _addCallSegment(
            intent,
            CallIntentSegmentBuilder.create(
                _accountBuyERC1155AndTransferERC721(nftPrice, _reqTokenId, address(_callIntentStandard))
            )
        );
        intent = _addAssetRequireSegment(
            intent,
            AssetRequireIntentSegmentBuilder.create().requireERC721(
                address(_testERC721), _reqTokenId, AssetCurveBuilder.constantCurve(0), false
            )
        );
        return intent;
    }

    function _solverIntentForCase(uint256 nftPrice) private view returns (UserIntent memory) {
        return _solverIntent(
            _solverBuyERC721AndForward(nftPrice, address(_account)),
            _solverSellERC721AndForward(_reqTokenId, address(_publicAddressSolver)),
            "",
            2
        );
    }

    function setUp() public override {
        super.setUp();

        //determine required token
        _reqTokenId = _testERC721.nextNFTForSale();

        //fund account
        vm.deal(address(_account), _accountInitialETHBalance);
    }

    // the max value uint64 can hold is just more than 10 ether,
    // that is the account's initial balance
    function testFuzz_conditionalPurchaseNFT(uint64 ethReleaseAmount) public {
        vm.assume(ethReleaseAmount < _accountInitialETHBalance - _testERC1155.nftCost());
        uint256 nftPrice = _testERC1155.nftCost();
        vm.assume(nftPrice < ethReleaseAmount);

        //create account intent
        UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(nftPrice);

        //create solution
        IntentSolution memory solution = _solution(intent, solverIntent);

        //simulate execution
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.ExecutionResult.selector, true, false, ""));
        _entryPoint.simulateHandleIntents(solution, address(0), "");

        //execute
        _entryPoint.handleIntents(solution);

        //verify end state
        uint256 solverBalance = address(_publicAddressSolver).balance;
        uint256 userBalance = address(_account).balance;
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        assertEq(solverBalance, ethReleaseAmount, "The solver ended up with incorrect balance");
        assertEq(
            userBalance,
            _accountInitialETHBalance - (ethReleaseAmount + nftPrice),
            "The user released more native tokens than expected"
        );
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
    }

    function test_failConditionalPurchaseNFT_insufficientReleaseBalance() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 ethReleaseAmount = _accountInitialETHBalance + 1;

        //create account intent
        UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
        intent = _signIntent(intent);

        //create solver intent
        UserIntent memory solverIntent = _solverIntentForCase(nftPrice);

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

    function test_failConditionalPurchaseNFT_outOfFund() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 ethReleaseAmount = 2 ether;

        //create account intent
        UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
        intent = _signIntent(intent);

        //create solver intent
        //attempt to buy nft with insufficient funds
        UserIntent memory solverIntent = _solverIntentForCase(_accountInitialETHBalance + 1);

        //create solution
        IntentSolution memory solution = _solution(intent, solverIntent);

        bytes memory encoded =
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 1, 0, "AA61 execution failed (or OOG)");

        //execute
        vm.expectRevert(encoded);
        _entryPoint.handleIntents(solution);
    }

    function test_failConditionalPurchaseNFT_wrongSignature() public {
        uint256 nftPrice = _testERC1155.nftCost();
        uint256 ethReleaseAmount = 2 ether;

        //create account intent
        UserIntent memory intent = _intentForCase(ethReleaseAmount, nftPrice);
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
