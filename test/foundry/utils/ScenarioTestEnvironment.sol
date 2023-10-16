// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import {IntentBuilder} from "./builders/IntentBuilder.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {IEntryPoint} from "../../../src/interfaces/IEntryPoint.sol";
import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {IntentSolution} from "../../../src/interfaces/IntentSolution.sol";
import {CallIntentStandard, CallIntentSegment} from "../../../src/standards/CallIntentStandard.sol";
import {CallIntentBuilder, CallIntentSegmentBuilder} from "./builders/standards/CallIntentBuilder.sol";
import {
    AssetReleaseIntentStandard,
    AssetReleaseIntentSegment
} from "../../../src/standards/AssetReleaseIntentStandard.sol";
import {AssetReleaseIntentBuilder} from "./builders/standards/AssetReleaseIntentBuilder.sol";
import {
    Erc20ReleaseIntentStandard,
    Erc20ReleaseIntentSegment
} from "../../../src/standards/Erc20ReleaseIntentStandard.sol";
import {
    Erc20ReleaseIntentBuilder,
    Erc20ReleaseIntentSegmentBuilder
} from "./builders/standards/Erc20ReleaseIntentBuilder.sol";
import {
    AssetRequireIntentStandard,
    AssetRequireIntentSegment
} from "../../../src/standards/AssetRequireIntentStandard.sol";
import {
    AssetRequireIntentBuilder,
    AssetRequireIntentSegmentBuilder
} from "./builders/standards/AssetRequireIntentBuilder.sol";
import {CurveBuilder} from "./builders/CurveBuilder.sol";
import {
    Erc20RequireIntentStandard,
    Erc20RequireIntentSegment
} from "../../../src/standards/Erc20RequireIntentStandard.sol";
import {
    Erc20RequireIntentBuilder,
    Erc20RequireIntentSegmentBuilder
} from "./builders/standards/Erc20RequireIntentBuilder.sol";
import {EthReleaseIntentStandard, EthReleaseIntentSegment} from "../../../src/standards/EthReleaseIntentStandard.sol";
import {
    EthReleaseIntentBuilder, EthReleaseIntentSegmentBuilder
} from "./builders/standards/EthReleaseIntentBuilder.sol";
import {EthRequireIntentStandard, EthRequireIntentSegment} from "../../../src/standards/EthRequireIntentStandard.sol";
import {
    EthRequireIntentBuilder, EthRequireIntentSegmentBuilder
} from "./builders/standards/EthRequireIntentBuilder.sol";
import {TestERC20} from "../../../src/test/TestERC20.sol";
import {TestERC721} from "../../../src/test/TestERC721.sol";
import {TestERC1155} from "../../../src/test/TestERC1155.sol";
import {TestUniswap} from "../../../src/test/TestUniswap.sol";
import {TestWrappedNativeToken} from "../../../src/test/TestWrappedNativeToken.sol";
import {SolverUtils} from "../../../src/test/SolverUtils.sol";
import {ValidationData, _packValidationData, _parseValidationData} from "../../../src/utils/Helpers.sol";
import {AbstractAccount} from "../../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

abstract contract ScenarioTestEnvironment is Test {
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    CallIntentStandard internal _callIntentStandard;
    AssetReleaseIntentStandard internal _assetReleaseIntentStandard;
    AssetRequireIntentStandard internal _assetRequireIntentStandard;
    EthReleaseIntentStandard internal _ethReleaseIntentStandard;
    EthRequireIntentStandard internal _ethRequireIntentStandard;
    Erc20ReleaseIntentStandard internal _erc20ReleaseIntentStandard;
    Erc20RequireIntentStandard internal _erc20RequireIntentStandard;
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
        _callIntentStandard = new CallIntentStandard(_entryPoint);
        _assetReleaseIntentStandard = new AssetReleaseIntentStandard(_entryPoint);
        _assetRequireIntentStandard = new AssetRequireIntentStandard(_entryPoint);
        _ethReleaseIntentStandard = new EthReleaseIntentStandard(_entryPoint);
        _ethRequireIntentStandard = new EthRequireIntentStandard(_entryPoint);
        _erc20ReleaseIntentStandard = new Erc20ReleaseIntentStandard(_entryPoint);
        _erc20RequireIntentStandard = new Erc20RequireIntentStandard(_entryPoint);
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //register intent standards to entry point
        _entryPoint.registerIntentStandard(_callIntentStandard);
        _entryPoint.registerIntentStandard(_assetReleaseIntentStandard);
        _entryPoint.registerIntentStandard(_assetRequireIntentStandard);
        _entryPoint.registerIntentStandard(_ethReleaseIntentStandard);
        _entryPoint.registerIntentStandard(_ethRequireIntentStandard);
        _entryPoint.registerIntentStandard(_erc20ReleaseIntentStandard);
        _entryPoint.registerIntentStandard(_erc20RequireIntentStandard);

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
     * Private helper function to build a call intent struct for the solver.
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
        UserIntent memory intent = IntentBuilder.create(address(_solverUtils), 0, 0);
        if (numSegments > 0) {
            intent = _addCallSegment(intent, CallIntentSegmentBuilder.create(callData1));
        }
        if (numSegments > 1) {
            intent = _addCallSegment(intent, CallIntentSegmentBuilder.create(callData2));
        }
        if (numSegments > 2) {
            intent = _addCallSegment(intent, CallIntentSegmentBuilder.create(callData3));
        }
        for (uint256 i = 3; i < numSegments; i++) {
            intent = _addCallSegment(intent, CallIntentSegmentBuilder.create(""));
        }

        return intent;
    }

    /**
     * Private helper function to build a user intent struct.
     * @return The created UserIntent struct.
     */
    function _intent() internal view returns (UserIntent memory) {
        return IntentBuilder.create(address(_account), 0, 0);
    }

    function _addAssetReleaseSegment(UserIntent memory intent, AssetReleaseIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return AssetReleaseIntentBuilder.addSegment(intent, _assetReleaseIntentStandard.standardId(), segment);
    }

    function _addAssetRequireSegment(UserIntent memory intent, AssetRequireIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return AssetRequireIntentBuilder.addSegment(intent, _assetRequireIntentStandard.standardId(), segment);
    }

    function _addEthReleaseSegment(UserIntent memory intent, EthReleaseIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return EthReleaseIntentBuilder.addSegment(intent, _ethReleaseIntentStandard.standardId(), segment);
    }

    function _addEthRequireSegment(UserIntent memory intent, EthRequireIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return EthRequireIntentBuilder.addSegment(intent, _ethRequireIntentStandard.standardId(), segment);
    }

    function _addErc20ReleaseSegment(UserIntent memory intent, Erc20ReleaseIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return Erc20ReleaseIntentBuilder.addSegment(intent, _erc20ReleaseIntentStandard.standardId(), segment);
    }

    function _addErc20RequireSegment(UserIntent memory intent, Erc20RequireIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return Erc20RequireIntentBuilder.addSegment(intent, _erc20RequireIntentStandard.standardId(), segment);
    }

    function _addCallSegment(UserIntent memory intent, CallIntentSegment memory segment)
        internal
        view
        returns (UserIntent memory)
    {
        return CallIntentBuilder.addSegment(intent, _callIntentStandard.standardId(), segment);
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
     * @param intent1 First intent that's part of the solution.
     * @param intent2 Second intent that's part of the solution.
     * @param order The order of intents to execute.
     * @return The created IntentSolution struct.
     */
    function _solution(UserIntent memory intent1, UserIntent memory intent2, uint256[] memory order)
        internal
        view
        returns (IntentSolution memory)
    {
        UserIntent[] memory intents = new UserIntent[](2);
        intents[0] = intent1;
        intents[1] = intent2;
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
