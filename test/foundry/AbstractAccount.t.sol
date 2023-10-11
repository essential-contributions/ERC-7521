// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/ScenarioTestEnvironment.sol";
import {
    IERC165, IERC721Receiver, IERC1155Receiver, TokenCallbackHandler
} from "../../src/wallet/TokenCallbackHandler.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

contract AbstractAccountTest is ScenarioTestEnvironment, TokenCallbackHandler {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;
    using ECDSA for bytes32;

    function test_entryPoint() public {
        assertEq(address(_account.entryPoint()), address(_entryPoint));
    }

    function test_getNonce() public {
        // nonce in the beginning
        assertEq(_account.getNonce(), 0);

        // user's intent
        UserIntent memory intent = _intent();
        intent = intent.addSegment(
            _assetBasedIntentStandard.standardId(),
            _segment(_accountClaimAirdropERC20(2 ether)).releaseERC20(
                address(_testERC20), AssetBasedIntentCurveBuilder.constantCurve(int256(1 ether))
            )
        );
        intent = _signIntent(intent);

        // solver's intent
        UserIntent memory solverIntent =
            _solverIntent(_solverSwapAllERC20ForETH(1 ether, address(_publicAddressSolver)), "", "", 1);

        //handle intents
        _entryPoint.handleIntents(_solution(intent, solverIntent));

        // nonce after execution
        assertEq(_account.getNonce(), 1);
    }

    function test_failExecuteMulti_invalidInputs() public {
        // targets.length != values.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](2);

        AssetBasedIntentSegment memory intentSegment = AssetBasedIntentSegmentBuilder.create(
            abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
        );

        UserIntent memory intent = _intent();
        intent = intent.addSegment(_assetBasedIntentStandard.standardId(), intentSegment);
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent("", "", "", 1));

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failExecuteMulti_invalidInputs2() public {
        // targets.length != datas.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](1);

        AssetBasedIntentSegment memory intentSegment = AssetBasedIntentSegmentBuilder.create(
            abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
        );

        UserIntent memory intent = _intent();
        intent = intent.addSegment(_assetBasedIntentStandard.standardId(), intentSegment);
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent("", "", "", 1));

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failCall() public {
        UserIntent memory intent = _intent();
        // account is not funded, the call will fail
        intent = intent.addSegment(
            _assetBasedIntentStandard.standardId(), _segment(_accountBuyERC1155(_testERC1155.nftCost()))
        );
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent("", "", "", 1));

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed (or OOG)")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_onERC721Received() public {
        uint256 price = _testERC721.nftCost();
        vm.deal(address(this), price);

        // test contract buy NFT
        uint256 tokenId = TestERC721(payable(address(_testERC721))).buyNFT{value: price}(address(this));

        // transfer NFT to account
        _transfer(AssetType.ERC721_ID, address(_testERC721), tokenId, address(this), address(_account), 1);

        // check account balance
        uint256 balance = _balanceOf(AssetType.ERC721_ID, address(_testERC721), tokenId, address(_account));
        assertEq(balance, 1);
    }

    function test_onERC1155Received() public {
        uint256 price = _testERC1155.nftCost();
        uint256 amount = 1;
        vm.deal(address(this), price);

        // test contract buy NFT
        uint256 tokenId = TestERC1155(payable(address(_testERC1155))).buyNFT{value: price}(address(this), amount);

        // transfer NFT to account
        _transfer(AssetType.ERC1155, address(_testERC1155), tokenId, address(this), address(_account), amount);

        // check account balance
        uint256 balance = _balanceOf(AssetType.ERC1155, address(_testERC1155), tokenId, address(_account));
        assertEq(balance, amount);
    }

    function test_onERC1155BatchReceived() public {
        uint256 price = _testERC1155.nftCost();
        uint256 amount = 5;
        uint256 totalPrice = price * amount;
        vm.deal(address(this), totalPrice);

        // test contract buy NFT
        uint256 tokenId = TestERC1155(payable(address(_testERC1155))).buyNFT{value: totalPrice}(address(this), amount);

        // transfer NFT to account
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        IERC1155(address(_testERC1155)).safeBatchTransferFrom(address(this), address(_account), assetIds, amounts, "");

        // check account balance
        uint256 balance = _balanceOf(AssetType.ERC1155, address(_testERC1155), tokenId, address(_account));
        assertEq(balance, amount);
    }

    function test_supportsInterface() public view {
        bool supportsIERC165 = _account.supportsInterface(type(IERC165).interfaceId);
        bool supportsIERC721Receiver = _account.supportsInterface(type(IERC721Receiver).interfaceId);
        bool supportsIERC1155Receiver = _account.supportsInterface(type(IERC1155Receiver).interfaceId);
        assert(supportsIERC165);
        assert(supportsIERC721Receiver);
        assert(supportsIERC1155Receiver);
    }
}
