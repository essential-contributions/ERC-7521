// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import {IntentBuilder} from "./IntentBuilder.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {IntentSolution} from "../../../src/interfaces/IntentSolution.sol";
import {DeployableErc20Record} from "../../../src/standards/deployable/DeployableErc20Record.sol";
import {DeployableErc20Release} from "../../../src/standards/deployable/DeployableErc20Release.sol";
import {DeployableErc20ReleaseExponential} from
    "../../../src/standards/deployable/DeployableErc20ReleaseExponential.sol";
import {DeployableErc20ReleaseLinear} from "../../../src/standards/deployable/DeployableErc20ReleaseLinear.sol";
import {DeployableErc20Require} from "../../../src/standards/deployable/DeployableErc20Require.sol";
import {DeployableErc20RequireExponential} from
    "../../../src/standards/deployable/DeployableErc20RequireExponential.sol";
import {DeployableErc20RequireLinear} from "../../../src/standards/deployable/DeployableErc20RequireLinear.sol";
import {DeployableEthReleaseExponential} from "../../../src/standards/deployable/DeployableEthReleaseExponential.sol";
import {DeployableEthReleaseLinear} from "../../../src/standards/deployable/DeployableEthReleaseLinear.sol";
import {DeployableEthRequireExponential} from "../../../src/standards/deployable/DeployableEthRequireExponential.sol";
import {DeployableEthRequireLinear} from "../../../src/standards/deployable/DeployableEthRequireLinear.sol";
import {DeployableSequentialNonce} from "../../../src/standards/deployable/DeployableSequentialNonce.sol";
import {EmbeddableSimpleCall} from "../../../src/standards/Embeddable/EmbeddableSimpleCall.sol";
import {EmbeddableUserOperation} from "../../../src/standards/Embeddable/EmbeddableUserOperation.sol";
import {EmbeddableEthRequire} from "../../../src/standards/Embeddable/EmbeddableEthRequire.sol";
import {EmbeddableEthRecord} from "../../../src/standards/Embeddable/EmbeddableEthRecord.sol";
import {EmbeddableEthRelease} from "../../../src/standards/Embeddable/EmbeddableEthRelease.sol";
import {BaseIntentStandard} from "../../../src/interfaces/BaseIntentStandard.sol";
import {TestERC20} from "../../../src/test/TestERC20.sol";
import {TestUniswap} from "../../../src/test/TestUniswap.sol";
import {TestWrappedNativeToken} from "../../../src/test/TestWrappedNativeToken.sol";
import {SolverUtils} from "../../../src/test/SolverUtils.sol";
import {AbstractAccount} from "../../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

abstract contract ScenarioTestEnvironment is Test {
    using IntentBuilder for UserIntent;
    using ECDSA for bytes32;

    //main contracts
    EntryPoint internal _entryPoint;
    AbstractAccount internal _account;

    //intent standard contracts
    DeployableErc20Record internal _erc20Record;
    DeployableErc20Release internal _erc20Release;
    DeployableErc20ReleaseExponential internal _erc20ReleaseExponential;
    DeployableErc20ReleaseLinear internal _erc20ReleaseLinear;
    DeployableErc20Require internal _erc20Require;
    DeployableErc20RequireExponential internal _erc20RequireExponential;
    DeployableErc20RequireLinear internal _erc20RequireLinear;
    DeployableEthReleaseExponential internal _ethReleaseExponential;
    DeployableEthReleaseLinear internal _ethReleaseLinear;
    DeployableEthRequireExponential internal _ethRequireExponential;
    DeployableEthRequireLinear internal _ethRequireLinear;
    DeployableSequentialNonce internal _sequentialNonce;
    EmbeddableSimpleCall internal _simpleCall;
    EmbeddableUserOperation internal _userOperation;
    EmbeddableEthRecord internal _ethRecord;
    EmbeddableEthRelease internal _ethRelease;
    EmbeddableEthRequire internal _ethRequire;

    //testing contracts
    TestERC20 internal _testERC20;
    TestUniswap internal _testUniswap;
    TestWrappedNativeToken internal _testWrappedNativeToken;
    SolverUtils internal _solverUtils;
    address internal _token;

    //keys
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
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //intent standards
        _erc20Record = new DeployableErc20Record();
        _erc20Release = new DeployableErc20Release();
        _erc20ReleaseExponential = new DeployableErc20ReleaseExponential();
        _erc20ReleaseLinear = new DeployableErc20ReleaseLinear();
        _erc20Require = new DeployableErc20Require();
        _erc20RequireExponential = new DeployableErc20RequireExponential();
        _erc20RequireLinear = new DeployableErc20RequireLinear();
        _ethRecord = EmbeddableEthRecord(address(_entryPoint));
        _ethRelease = EmbeddableEthRelease(address(_entryPoint));
        _ethReleaseExponential = new DeployableEthReleaseExponential();
        _ethReleaseLinear = new DeployableEthReleaseLinear();
        _ethRequire = EmbeddableEthRequire(address(_entryPoint));
        _ethRequireExponential = new DeployableEthRequireExponential();
        _ethRequireLinear = new DeployableEthRequireLinear();
        _sequentialNonce = new DeployableSequentialNonce();
        _simpleCall = EmbeddableSimpleCall(address(_entryPoint));
        _userOperation = EmbeddableUserOperation(address(_entryPoint));

        //register intent standards to entry point
        _entryPoint.registerIntentStandard(_erc20Record);
        _entryPoint.registerIntentStandard(_erc20Release);
        _entryPoint.registerIntentStandard(_erc20ReleaseExponential);
        _entryPoint.registerIntentStandard(_erc20ReleaseLinear);
        _entryPoint.registerIntentStandard(_erc20Require);
        _entryPoint.registerIntentStandard(_erc20RequireExponential);
        _entryPoint.registerIntentStandard(_erc20RequireLinear);
        _entryPoint.registerIntentStandard(_ethReleaseExponential);
        _entryPoint.registerIntentStandard(_ethReleaseLinear);
        _entryPoint.registerIntentStandard(_ethRequireExponential);
        _entryPoint.registerIntentStandard(_ethRequireLinear);
        _entryPoint.registerIntentStandard(_sequentialNonce);

        //deploy test contracts
        _testERC20 = new TestERC20();
        _testWrappedNativeToken = new TestWrappedNativeToken();
        _testUniswap = new TestUniswap(_testWrappedNativeToken);
        _solverUtils = new SolverUtils(_testUniswap, _testERC20, _testWrappedNativeToken);
        _token = address(_testERC20);

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
     * Private helper function to build call data for the solver to swap tokens and forward some ETH.
     * @param minETH The minimum amount of ETH to be received after the swap.
     * @param to The address to receive the swapped ETH.
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     * @return The encoded call data for the swap and forward action.
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

    /**
     * Private helper function to build call data for the solver to transfer the test ERC20 token.
     * @param recipient The token recipient.
     * @param amount The amount of tokens to transfer.
     * @return The encoded call data for the transfer action.
     */
    function _solverTransferERC20(address recipient, uint256 amount) internal view returns (bytes memory) {
        return abi.encodeWithSelector(SolverUtils.transferERC20.selector, _testERC20, recipient, amount);
    }

    /**
     * Private helper function to build call data for the solver to transfer ETH.
     * @param recipient The token recipient.
     * @param amount The amount of ETH to transfer.
     * @return The encoded call data for the transfer action.
     */
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
            intent = _addSimpleCall(intent, callData1);
        }
        if (numSegments > 1) {
            intent = _addSimpleCall(intent, callData2);
        }
        if (numSegments > 2) {
            intent = _addSimpleCall(intent, callData3);
        }
        for (uint256 i = 3; i < numSegments; i++) {
            intent = _addSimpleCall(intent, "");
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

    function _addErc20Record(UserIntent memory intent) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20Record);
        return intent.addSegment(_erc20Record.encodeData(standardId, _token));
    }

    function _addErc20Release(UserIntent memory intent, int256 amount) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20Release);
        return intent.addSegment(_erc20Release.encodeData(standardId, _token, amount));
    }

    function _addErc20ReleaseExponential(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20ReleaseExponential);
        return intent.addSegment(
            _erc20ReleaseExponential.encodeData(
                standardId, _token, startTime, deltaTime, startAmount, deltaAmount, exponent, backwards
            )
        );
    }

    function _addErc20ReleaseLinear(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20ReleaseLinear);
        return intent.addSegment(
            _erc20ReleaseLinear.encodeData(standardId, _token, startTime, deltaTime, startAmount, deltaAmount)
        );
    }

    function _addErc20Require(UserIntent memory intent, int256 amount, bool isRelative)
        internal
        view
        returns (UserIntent memory)
    {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20Require);
        return intent.addSegment(_erc20Require.encodeData(standardId, _token, amount, isRelative));
    }

    function _addErc20RequireExponential(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards,
        bool isRelative
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20RequireExponential);
        return intent.addSegment(
            _erc20RequireExponential.encodeData(
                standardId, _token, startTime, deltaTime, startAmount, deltaAmount, exponent, backwards, isRelative
            )
        );
    }

    function _addErc20RequireLinear(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        bool isRelative
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_erc20RequireLinear);
        return intent.addSegment(
            _erc20RequireLinear.encodeData(
                standardId, _token, startTime, deltaTime, startAmount, deltaAmount, isRelative
            )
        );
    }

    function _addEthRecord(UserIntent memory intent) internal view returns (UserIntent memory) {
        return intent.addSegment(_ethRecord.encodeData(_entryPoint.getEthRecordStandardId()));
    }

    function _addEthRelease(UserIntent memory intent, int256 amount) internal view returns (UserIntent memory) {
        return intent.addSegment(_ethRelease.encodeData(_entryPoint.getEthReleaseStandardId(), amount));
    }

    function _addEthReleaseExponential(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseExponential);
        return intent.addSegment(
            _ethReleaseExponential.encodeData(
                standardId, startTime, deltaTime, startAmount, deltaAmount, exponent, backwards
            )
        );
    }

    function _addEthReleaseLinear(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethReleaseLinear);
        return
            intent.addSegment(_ethReleaseLinear.encodeData(standardId, startTime, deltaTime, startAmount, deltaAmount));
    }

    function _addEthRequire(UserIntent memory intent, int256 amount, bool isRelative)
        internal
        view
        returns (UserIntent memory)
    {
        return intent.addSegment(_ethRequire.encodeData(_entryPoint.getEthRequireStandardId(), amount, isRelative));
    }

    function _addEthRequireExponential(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards,
        bool isRelative
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethRequireExponential);
        return intent.addSegment(
            _ethRequireExponential.encodeData(
                standardId, startTime, deltaTime, startAmount, deltaAmount, exponent, backwards, isRelative
            )
        );
    }

    function _addEthRequireLinear(
        UserIntent memory intent,
        uint40 startTime,
        uint32 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        bool isRelative
    ) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethRequireLinear);
        return intent.addSegment(
            _ethRequireLinear.encodeData(standardId, startTime, deltaTime, startAmount, deltaAmount, isRelative)
        );
    }

    function _addSequentialNonce(UserIntent memory intent, uint256 nonce) internal view returns (UserIntent memory) {
        bytes32 standardId = _entryPoint.getIntentStandardId(_sequentialNonce);
        return intent.addSegment(_sequentialNonce.encodeData(standardId, nonce));
    }

    function _addSimpleCall(UserIntent memory intent, bytes memory callData)
        internal
        view
        returns (UserIntent memory)
    {
        return intent.addSegment(_simpleCall.encodeData(_entryPoint.getSimpleCallStandardId(), callData));
    }

    function _addUserOp(UserIntent memory intent, uint32 callGasLimit, bytes memory callData)
        internal
        view
        returns (UserIntent memory)
    {
        return intent.addSegment(
            _userOperation.encodeData(_entryPoint.getUserOperationStandardId(), callGasLimit, callData)
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

    /**
     * Private helper function to add an invalid signature to an intent.
     * @param intent The UserIntent struct representing the user's intent.
     * @return The UserIntent struct with the added signature.
     */
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

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
