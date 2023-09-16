// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import {
    AssetBasedIntentBuilder,
    AssetBasedIntentCurveBuilder,
    AssetBasedIntentSegmentBuilder
} from "./AssetBasedIntentBuilder.sol";
import {DefaultIntentBuilder} from "./DefaultIntentBuilder.sol";
import {EntryPoint} from "../../src/core/EntryPoint.sol";
import {IEntryPoint} from "../../src/interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../src/interfaces/UserIntent.sol";
import {IntentSolution} from "../../src/interfaces/IntentSolution.sol";
import {
    AssetBasedIntentCurve,
    AssetBasedIntentCurveLib,
    CurveType,
    EvaluationType
} from "../../src/types/assetbased/AssetBasedIntentCurve.sol";
import {AssetBasedIntentSegment} from "../../src/types/assetbased/AssetBasedIntentSegment.sol";
import {AssetBasedIntentType} from "../../src/types/assetbased/AssetBasedIntentType.sol";
import {AssetType, _balanceOf, _transfer} from "../../src/types/assetbased/utils/AssetWrapper.sol";
import {TestERC20} from "../../src/test/TestERC20.sol";
import {TestERC721} from "../../src/test/TestERC721.sol";
import {TestERC1155} from "../../src/test/TestERC1155.sol";
import {TestUniswap} from "../../src/test/TestUniswap.sol";
import {TestWrappedNativeToken} from "../../src/test/TestWrappedNativeToken.sol";
import {SolverUtils} from "../../src/test/SolverUtils.sol";
import {ValidationData, _packValidationData, _parseValidationData} from "../../src/utils/Helpers.sol";
import {AbstractAccount} from "../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

abstract contract ScenarioTestEnvironment is Test {
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    AssetBasedIntentType internal _assetBasedIntentType;
    AbstractAccount internal _account;

    TestERC20 internal _testERC20;
    TestERC721 internal _testERC721;
    TestERC1155 internal _testERC1155;
    TestUniswap internal _testUniswap;
    TestWrappedNativeToken internal _testWrappedNativeToken;
    SolverUtils internal _solverUtils;

    uint256 internal constant _privateKey = uint256(keccak256("account_private_key"));
    address internal _publicAddress = _getPublicAddress(_privateKey);

    uint256 internal constant _privateKeySolver = uint256(keccak256("solver_private_key"));
    address internal _publicAddressSolver = _getPublicAddress(_privateKeySolver);

    uint256 internal constant _wrong_private_key = uint256(keccak256("wrong_account_private_key"));
    address internal _wrongPublicAddress = _getPublicAddress(_wrong_private_key);

    /**
     * Sets up the testing environment with mock tokens and AMMs.
     */
    function setUp() public virtual {
        //deploy contracts
        _entryPoint = new EntryPoint();
        _assetBasedIntentType = new AssetBasedIntentType(_entryPoint);
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //register asset based intent type to entry point
        _entryPoint.registerIntentType(_assetBasedIntentType);

        _testERC20 = new TestERC20();
        _testERC721 = new TestERC721();
        _testERC1155 = new TestERC1155();
        _testWrappedNativeToken = new TestWrappedNativeToken();
        _testUniswap = new TestUniswap(_testWrappedNativeToken);
        _solverUtils = new SolverUtils(_testUniswap, _testERC20, _testWrappedNativeToken);

        //fund exchange
        _testERC20.mint(address(_testUniswap), 1000 ether);
        _mintWrappedNativeToken(address(_testUniswap), 1000 ether);
    }

    /**
     * Private helper function to quickly mint wrapped native tokens.
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function _mintWrappedNativeToken(address to, uint256 amount) internal {
        vm.deal(address(this), amount);
        _testWrappedNativeToken.deposit{value: amount}();
        _testWrappedNativeToken.transfer(to, amount);
    }

    /**
     * Private helper function to build call data for the account buying an ERC721 NFT.
     * @param price The price of the ERC721 NFT to buy.
     * @return The encoded call data for the buy action.
     */
    function _accountBuyERC721(uint256 price) internal view returns (bytes memory) {
        bytes memory buyCall = abi.encodeWithSelector(TestERC721.buyNFT.selector, address(_account));
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC721, price, buyCall);
    }

    /**
     * Private helper function to build call data for the account buying an ERC1155 NFT.
     * @param price The price of the ERC1155 NFT to buy.
     * @return The encoded call data for the buy action.
     */
    function _accountBuyERC1155(uint256 price) internal view returns (bytes memory) {
        bytes memory buyCall = abi.encodeWithSelector(TestERC1155.buyNFT.selector, address(_account), 1);
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC1155, price, buyCall);
    }

    /**
     * Private helper function to build call data for the account buying an ERC1155 NFT and then transferring an ERC721.
     * @param price The price of the ERC1155 NFT to buy.
     * @param transferAssetId The ID of the ERC721 token to transfer after buying the ERC1155.
     * @param transferTo The address to transfer the ERC721 token to.
     * @return The encoded call data for the buy and transfer actions.
     */
    function _accountBuyERC1155AndTransferERC721(uint256 price, uint256 transferAssetId, address transferTo)
        internal
        view
        returns (bytes memory)
    {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = address(_testERC1155);
        datas[0] = abi.encodeWithSelector(TestERC1155.buyNFT.selector, address(_account), 1);
        values[0] = price;

        targets[1] = address(_testERC721);
        datas[1] = abi.encodeWithSelector(
            IERC721.transferFrom.selector, address(_account), address(transferTo), transferAssetId
        );

        return abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas);
    }

    /**
     * Private helper function to build call data for the account claiming an ERC20 airdrop.
     * @param amount The amount of ERC20 tokens to claim in the airdrop.
     * @return The encoded call data for the claim airdrop action.
     */
    function _accountClaimAirdropERC20(uint256 amount) internal view returns (bytes memory) {
        bytes memory mintCall = abi.encodeWithSelector(TestERC20.mint.selector, address(_account), amount);
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC20, 0, mintCall);
    }

    /**
     * Private helper function to build call data for the solver to swap tokens.
     * @param minETH The minimum amount of ETH to be received after the swap.
     * @param to The address to receive the swapped ETH.
     * @return The array of solution steps for swapping tokens.
     */
    function _solverSwapAllERC20ForETH(uint256 minETH, address to) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            SolverUtils.swapAllERC20ForETH.selector, _testUniswap, _testERC20, _testWrappedNativeToken, minETH, to
        );
    }

    /**
     * Private helper function to build call data for the solver to swap tokens and forward some ETH.
     * @param minETH The minimum amount of ETH to be received after the swap.
     * @param to The address to receive the swapped ETH.
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     * @return The array of solution steps for swapping tokens and forwarding ETH.
     */
    function _solverSwapAllERC20ForETHAndForward(uint256 minETH, address to, uint256 forwardAmount, address forwardTo)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            SolverUtils.swapAllERC20ForETHAndForward.selector,
            _testUniswap,
            _testERC20,
            _testWrappedNativeToken,
            minETH,
            to,
            forwardAmount,
            forwardTo
        );
    }

    /**
     * Private helper function to build call data for the solver to buying and forwarding an ERC721 token.
     * @param price The price of the ERC721 token to buy.
     * @param to The address to forward the purchased ERC721 token to.
     * @return The array of solution steps for buying and forwarding an ERC721 token.
     */
    function _solverBuyERC721AndForward(uint256 price, address to) internal view returns (bytes memory) {
        return abi.encodeWithSelector(SolverUtils.buyERC721.selector, _testERC721, price, to);
    }

    /**
     * Private helper function to build call data for the solver to swap tokens and forward some ETH.
     * @param minETH The minimum amount of ETH to be received after the swap.
     * @param nftPrice The price required to buy the NFT.
     * @param forwardETHAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     * @return The array of solution steps for swapping tokens and forwarding ETH.
     */
    function _solverSwapAllERC20ForETHBuyNFTAndForward(
        uint256 minETH,
        uint256 nftPrice,
        uint256 forwardETHAmount,
        address forwardTo
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            SolverUtils.swapAllERC20ForETHBuyNFTAndForward.selector,
            _testUniswap,
            _testERC721,
            _testERC20,
            _testWrappedNativeToken,
            minETH,
            nftPrice,
            forwardETHAmount,
            forwardTo
        );
    }

    /**
     * Private helper function to build call data for the solver to selling an ERC721 token and forwarding ETH.
     * @param tokenId The ID of the ERC721 token to sell.
     * @param to The address to forward the received ETH to.
     * @return The array of solution steps for selling an ERC721 token and forwarding ETH.
     */
    function _solverSellERC721AndForward(uint256 tokenId, address to) internal view returns (bytes memory) {
        return abi.encodeWithSelector(SolverUtils.sellERC721AndForwardAll.selector, _testERC721, tokenId, to);
    }

    /**
     * Private helper function to build a default intent struct for the solver.
     * @param callData1 Optoinal calldata for segment1.
     * @param callData2 Optoinal calldata for segment2.
     * @param callData3 Optoinal calldata for segment3.
     * @param numSegments The number of segments for the intent.
     * @return The created UserIntent struct.
     */
    function _solverIntent(bytes memory callData1, bytes memory callData2, bytes memory callData3, uint256 numSegments)
        internal
        view
        returns (UserIntent memory)
    {
        UserIntent memory intent =
            DefaultIntentBuilder.create(_entryPoint.getDefaultIntentTypeId(), address(_solverUtils), 0, 0);
        if (numSegments > 0) intent = DefaultIntentBuilder.addSegment(intent, callData1);
        if (numSegments > 1) intent = DefaultIntentBuilder.addSegment(intent, callData2);
        if (numSegments > 2) intent = DefaultIntentBuilder.addSegment(intent, callData3);
        for (uint256 i = 3; i < numSegments; i++) {
            intent = DefaultIntentBuilder.addSegment(intent, "");
        }

        return intent;
    }

    /**
     * Private helper function to build an empty intent struct for the solver.
     * @return The created UserIntent struct.
     */
    function _emptyIntent() internal view returns (UserIntent memory) {
        UserIntent memory intent =
            DefaultIntentBuilder.create(_entryPoint.getDefaultIntentTypeId(), address(_account), 0, 0);
        return intent;
    }

    /**
     * Private helper function to build an asset-based intent struct.
     * @return The created UserIntent struct.
     */
    function _intent() internal view returns (UserIntent memory) {
        return AssetBasedIntentBuilder.create(_assetBasedIntentType.typeId(), address(_account), 0, 0);
    }

    /**
     * Private helper function to build an asset-based intent struct.
     * @param callData The data for an intended call.
     * @return The created AssetBasedIntentSegment struct.
     */
    function _segment(bytes memory callData) internal pure returns (AssetBasedIntentSegment memory) {
        return AssetBasedIntentSegmentBuilder.create(callData);
    }

    /**
     * Private helper function to build an intent solution struct.
     * @param intent1 First intent that's part of the solution.
     * @param intent2 Second intent that's part of the solution.
     * @return The created IntentSolution struct.
     */
    function _solution(UserIntent memory intent1, UserIntent memory intent2)
        internal
        view
        returns (IntentSolution memory)
    {
        UserIntent[] memory intents = new UserIntent[](2);
        intents[0] = intent1;
        intents[1] = intent2;
        uint256[] memory order = new uint256[](0);
        return IntentSolution({timestamp: block.timestamp, intents: intents, order: order});
    }

    /**
     * Private helper function to build an intent solution struct.
     * @return The created IntentSolution struct.
     */
    function _emptySolution() internal view returns (IntentSolution memory) {
        UserIntent[] memory intents = new UserIntent[](0);
        uint256[] memory order = new uint256[](0);
        return IntentSolution({timestamp: block.timestamp, intents: intents, order: order});
    }

    /**
     * Private helper function to build an intent solution struct with a single intent.
     * @param intent Intent to include in the solution.
     * @return The created IntentSolution struct.
     */
    function _singleIntentSolution(UserIntent memory intent) internal view returns (IntentSolution memory) {
        UserIntent[] memory intents = new UserIntent[](1);
        intents[0] = intent;
        uint256[] memory order = new uint256[](0);
        return IntentSolution({timestamp: block.timestamp, intents: intents, order: order});
    }

    /**
     * Private helper function to turn a single intent struct into an array.
     * @param intent The intent to turn into an array.
     * @return The created intent array.
     */
    function _singleIntent(UserIntent memory intent) internal pure returns (UserIntent[] memory) {
        UserIntent[] memory intents = new UserIntent[](1);
        intents[0] = intent;
        return intents;
    }

    /**
     * Private helper function to add the account owner's signature to an intent.
     * @param intent The UserIntent struct representing the user's intent.
     * @return The UserIntent struct with the added signature.
     */
    function _signIntent(UserIntent memory intent) internal view returns (UserIntent memory) {
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        intent.signature = abi.encodePacked(r, s, v);
        return intent;
    }

    function _signIntentWithWrongKey(UserIntent memory intent) internal view returns (UserIntent memory) {
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_wrong_private_key, digest);
        intent.signature = abi.encodePacked(r, s, v);
        return intent;
    }

    /**
     * Private helper function to get the public address of a private key.
     * @param privateKey The private key to derive the public address from.
     * @return The derived public address.
     */
    function _getPublicAddress(uint256 privateKey) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked("test data"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return ecrecover(digest, v, r, s);
    }

    function test_nothing() public {}
}
