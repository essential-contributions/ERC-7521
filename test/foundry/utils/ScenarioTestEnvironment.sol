// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import {IntentBuilder} from "./builders/IntentBuilder.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {IEntryPoint} from "../../../src/interfaces/IEntryPoint.sol";
import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {IntentSolution} from "../../../src/interfaces/IntentSolution.sol";
import {
    Erc20ReleaseIntentStandard,
    Erc20ReleaseIntentSegment
} from "../../../src/standards/Erc20ReleaseIntentStandard.sol";
import {
    Erc20ReleaseIntentBuilder,
    Erc20ReleaseIntentSegmentBuilder
} from "./builders/standards/Erc20ReleaseIntentBuilder.sol";
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
import {CallIntentStandard, CallIntentSegment} from "../../../src/standards/CallIntentStandard.sol";
import {CallIntentBuilder, CallIntentSegmentBuilder} from "./builders/standards/CallIntentBuilder.sol";
import {UserOperation, UserOperationSegment} from "../../../src/standards/UserOperation.sol";
import {UserOperationBuilder, UserOperationSegmentBuilder} from "./builders/standards/UserOperationBuilder.sol";
import {SequentialNonce, SequentialNonceSegment} from "../../../src/standards/SequentialNonce.sol";
import {SequentialNonceBuilder, SequentialNonceSegmentBuilder} from "./builders/standards/SequentialNonceBuilder.sol";
import {TestERC20} from "../../../src/test/TestERC20.sol";
import {TestUniswap} from "../../../src/test/TestUniswap.sol";
import {TestWrappedNativeToken} from "../../../src/test/TestWrappedNativeToken.sol";
import {SolverUtils} from "../../../src/test/SolverUtils.sol";
import {AbstractAccount} from "../../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

abstract contract ScenarioTestEnvironment is Test {
    using EthReleaseIntentSegmentBuilder for EthReleaseIntentSegment;
    using EthRequireIntentSegmentBuilder for EthRequireIntentSegment;
    using Erc20ReleaseIntentSegmentBuilder for Erc20ReleaseIntentSegment;
    using Erc20RequireIntentSegmentBuilder for Erc20RequireIntentSegment;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    CallIntentStandard internal _callIntentStandard;
    UserOperation internal _userOperation;
    SequentialNonce internal _sequentialNonce;
    EthReleaseIntentStandard internal _ethReleaseIntentStandard;
    EthRequireIntentStandard internal _ethRequireIntentStandard;
    Erc20ReleaseIntentStandard internal _erc20ReleaseIntentStandard;
    Erc20RequireIntentStandard internal _erc20RequireIntentStandard;
    AbstractAccount internal _account;

    TestERC20 internal _testERC20;
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
        _callIntentStandard = CallIntentStandard(_entryPoint);
        _userOperation = new UserOperation();
        _sequentialNonce = new SequentialNonce();
        _ethReleaseIntentStandard = new EthReleaseIntentStandard();
        _ethRequireIntentStandard = new EthRequireIntentStandard();
        _erc20ReleaseIntentStandard = new Erc20ReleaseIntentStandard();
        _erc20RequireIntentStandard = new Erc20RequireIntentStandard();
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //register intent standards to entry point
        _entryPoint.registerIntentStandard(_userOperation);
        _entryPoint.registerIntentStandard(_sequentialNonce);
        _entryPoint.registerIntentStandard(_ethReleaseIntentStandard);
        _entryPoint.registerIntentStandard(_ethRequireIntentStandard);
        _entryPoint.registerIntentStandard(_erc20ReleaseIntentStandard);
        _entryPoint.registerIntentStandard(_erc20RequireIntentStandard);

        _testERC20 = new TestERC20();
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
    function _solverSwapERC20ForETH(uint256 minETH, address to) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            SolverUtils.swapERC20ForETH.selector, _testUniswap, _testERC20, _testWrappedNativeToken, minETH, to
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
    function _solverSwapERC20ForETHAndForward(uint256 minETH, address to, uint256 forwardAmount, address forwardTo)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            SolverUtils.swapERC20ForETHAndForward.selector,
            _testUniswap,
            _testERC20,
            _testWrappedNativeToken,
            minETH,
            to,
            forwardAmount,
            forwardTo
        );
    }

    function _solverTransferERC20(address recipient, uint256 amount) internal view returns (bytes memory) {
        return abi.encodeWithSelector(SolverUtils.transferERC20.selector, _testERC20, recipient, amount);
    }

    function _solverTransferETH(address recipient, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(SolverUtils.transferETH.selector, recipient, amount);
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
        UserIntent memory intent = IntentBuilder.create(address(_solverUtils));
        if (numSegments > 0) {
            intent = _addCallSegment(intent, callData1);
        }
        if (numSegments > 1) {
            intent = _addCallSegment(intent, callData2);
        }
        if (numSegments > 2) {
            intent = _addCallSegment(intent, callData3);
        }
        for (uint256 i = 3; i < numSegments; i++) {
            intent = _addCallSegment(intent, "");
        }

        return intent;
    }

    /**
     * Private helper function to build a user intent struct.
     * @return The created UserIntent struct.
     */
    function _intent() internal view returns (UserIntent memory) {
        return IntentBuilder.create(address(_account));
    }

    function _addEthReleaseSegment(UserIntent memory intent, int256[] memory curve)
        internal
        view
        returns (UserIntent memory)
    {
        return EthReleaseIntentBuilder.addSegment(
            intent,
            EthReleaseIntentSegmentBuilder.create(_entryPoint.getIntentStandardId(_ethReleaseIntentStandard)).releaseEth(
                0, curve
            )
        );
    }

    function _addEthRequireSegment(UserIntent memory intent, int256[] memory curve, bool relative)
        internal
        view
        returns (UserIntent memory)
    {
        return EthRequireIntentBuilder.addSegment(
            intent,
            EthRequireIntentSegmentBuilder.create(_entryPoint.getIntentStandardId(_ethRequireIntentStandard)).requireEth(
                0, curve, relative
            )
        );
    }

    function _addErc20ReleaseSegment(UserIntent memory intent, address addr, int256[] memory curve)
        internal
        view
        returns (UserIntent memory)
    {
        return Erc20ReleaseIntentBuilder.addSegment(
            intent,
            Erc20ReleaseIntentSegmentBuilder.create(_entryPoint.getIntentStandardId(_erc20ReleaseIntentStandard))
                .releaseErc20(addr, 0, curve)
        );
    }

    function _addErc20RequireSegment(UserIntent memory intent, address addr, int256[] memory curve, bool relative)
        internal
        view
        returns (UserIntent memory)
    {
        return Erc20RequireIntentBuilder.addSegment(
            intent,
            Erc20RequireIntentSegmentBuilder.create(_entryPoint.getIntentStandardId(_erc20RequireIntentStandard))
                .requireErc20(addr, 0, curve, relative)
        );
    }

    function _addCallSegment(UserIntent memory intent, bytes memory callData)
        internal
        view
        returns (UserIntent memory)
    {
        return CallIntentBuilder.addSegment(
            intent, CallIntentSegmentBuilder.create(_callIntentStandard.standardId(), callData)
        );
    }

    function _addUserOperationSegment(UserIntent memory intent, bytes memory callData, uint256 txGas)
        internal
        view
        returns (UserIntent memory)
    {
        return UserOperationBuilder.addSegment(
            intent, UserOperationSegmentBuilder.create(_entryPoint.getIntentStandardId(_userOperation), callData, txGas)
        );
    }

    function _addSequentialNonceSegment(UserIntent memory intent, uint256 nonce)
        internal
        view
        returns (UserIntent memory)
    {
        return SequentialNonceBuilder.addSegment(
            intent, SequentialNonceSegmentBuilder.create(_entryPoint.getIntentStandardId(_sequentialNonce), nonce)
        );
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
