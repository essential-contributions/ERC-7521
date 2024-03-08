// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import {IntentBuilder} from "./IntentBuilder.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {IntentSolution} from "../../../src/interfaces/IntentSolution.sol";
import {Erc20Record, encodeErc20RecordData} from "../../../src/standards/Erc20Record.sol";
import {ERC20_RECORD_STD_ID} from "../../../src/core/EntryPoint.sol";
import {
    Erc20Release,
    encodeErc20ReleaseData,
    encodeErc20ReleaseComplexData
} from "../../../src/standards/Erc20Release.sol";
import {ERC20_RELEASE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {
    Erc20Require,
    encodeErc20RequireData,
    encodeErc20RequireComplexData
} from "../../../src/standards/Erc20Require.sol";
import {ERC20_REQUIRE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {EthRecord, encodeEthRecordData} from "../../../src/standards/EthRecord.sol";
import {ETH_RECORD_STD_ID} from "../../../src/core/EntryPoint.sol";
import {EthRelease, encodeEthReleaseData, encodeEthReleaseComplexData} from "../../../src/standards/EthRelease.sol";
import {ETH_RELEASE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {EthRequire, encodeEthRequireData, encodeEthRequireComplexData} from "../../../src/standards/EthRequire.sol";
import {ETH_REQUIRE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {SequentialNonce, encodeSequentialNonceData} from "../../../src/standards/SequentialNonce.sol";
import {SEQUENTIAL_NONCE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {SimpleCall, encodeSimpleCallData} from "../../../src/standards/SimpleCall.sol";
import {SIMPLE_CALL_STD_ID} from "../../../src/core/EntryPoint.sol";
import {UserOperation, encodeUserOperationData} from "../../../src/standards/UserOperation.sol";
import {USER_OPERATION_STD_ID} from "../../../src/core/EntryPoint.sol";
import {FailingStandard} from "../../../src/test/FailingStandard.sol";
import {TestAggregator, ADMIN_SIGNATURE} from "../../../src/test/TestAggregator.sol";
import {TestAggregationAccount} from "../../../src/test/TestAggregationAccount.sol";
import {TestERC20} from "../../../src/test/TestERC20.sol";
import {TestUniswap} from "../../../src/test/TestUniswap.sol";
import {TestWrappedNativeToken} from "../../../src/test/TestWrappedNativeToken.sol";
import {SolverUtils} from "../../../src/test/SolverUtils.sol";
import {SimpleAccountFactory} from "../../../src/samples/SimpleAccountFactory.sol";
import {SimpleAccount} from "../../../src/samples/SimpleAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

abstract contract TestEnvironment is Test {
    using IntentBuilder for UserIntent;
    using ECDSA for bytes32;

    //main contracts
    EntryPoint internal _entryPoint;
    Erc20Record internal _erc20RecordStandard;
    Erc20Release internal _erc20ReleaseStandard;
    Erc20Require internal _erc20RequireStandard;
    EthRecord internal _ethRecordStandard;
    EthRelease internal _ethReleaseStandard;
    EthRequire internal _ethRequireStandard;
    SequentialNonce internal _sequentialNonceStandard;
    SimpleCall internal _simpleCallStandard;
    UserOperation internal _userOperationStandard;

    //accounts
    SimpleAccount internal _account;
    SimpleAccount internal _account2;
    SimpleAccount internal _account3;
    SimpleAccount internal _account4;

    //testing contracts
    FailingStandard internal _failingStandard;
    TestAggregator internal _testAggregator;
    TestAggregationAccount internal _testAggregationAccount;
    TestAggregationAccount internal _testAggregationAccount2;
    TestERC20 internal _testERC20;
    TestUniswap internal _testUniswap;
    TestWrappedNativeToken internal _testWrappedNativeToken;
    SolverUtils internal _solverUtils;

    //helpful values to remember
    bytes32 internal _erc20RecordStdId;
    bytes32 internal _erc20ReleaseStdId;
    bytes32 internal _erc20RequireStdId;
    bytes32 internal _ethRecordStdId;
    bytes32 internal _ethReleaseStdId;
    bytes32 internal _ethRequireStdId;
    bytes32 internal _sequentialNonceStdId;
    bytes32 internal _simpleCallStdId;
    bytes32 internal _userOperationStdId;
    bytes32 internal _failingStdId;
    address internal _token;

    //keys
    uint256 internal constant _privateKey = uint256(keccak256("account_private_key"));
    address internal _publicAddress = _getPublicAddress(_privateKey);
    uint256 internal constant _privateKey2 = uint256(keccak256("account_private_key2"));
    address internal _publicAddress2 = _getPublicAddress(_privateKey2);
    uint256 internal constant _privateKey3 = uint256(keccak256("account_private_key3"));
    address internal _publicAddress3 = _getPublicAddress(_privateKey3);
    uint256 internal constant _privateKey4 = uint256(keccak256("account_private_key4"));
    address internal _publicAddress4 = _getPublicAddress(_privateKey4);

    //recipients
    address internal _recipientAddress = 0x1234123412341234123412341234123412341234;
    address internal _recipientAddress2 = 0x5678567856785678567856785678567856785678;
    address internal _recipientAddress3 = 0x3456345634563456345634563456345634563456;
    address internal _recipientAddress4 = 0x7890789078907890789078907890789078907890;

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

        //add registered versions of standards
        _erc20RecordStandard = new Erc20Record();
        _erc20ReleaseStandard = new Erc20Release();
        _erc20RequireStandard = new Erc20Require();
        _ethRecordStandard = new EthRecord();
        _ethReleaseStandard = new EthRelease();
        _ethRequireStandard = new EthRequire();
        _sequentialNonceStandard = new SequentialNonce();
        _simpleCallStandard = new SimpleCall();
        _userOperationStandard = new UserOperation();
        _erc20RecordStdId = _entryPoint.registerIntentStandard(_erc20RecordStandard);
        _erc20ReleaseStdId = _entryPoint.registerIntentStandard(_erc20ReleaseStandard);
        _erc20RequireStdId = _entryPoint.registerIntentStandard(_erc20RequireStandard);
        _ethRecordStdId = _entryPoint.registerIntentStandard(_ethRecordStandard);
        _ethReleaseStdId = _entryPoint.registerIntentStandard(_ethReleaseStandard);
        _ethRequireStdId = _entryPoint.registerIntentStandard(_ethRequireStandard);
        _sequentialNonceStdId = _entryPoint.registerIntentStandard(_sequentialNonceStandard);
        _simpleCallStdId = _entryPoint.registerIntentStandard(_simpleCallStandard);
        _userOperationStdId = _entryPoint.registerIntentStandard(_userOperationStandard);

        //deploy accounts
        SimpleAccountFactory accountFactory = new SimpleAccountFactory(_entryPoint);
        _account = accountFactory.createAccount(_publicAddress, 111);
        _account2 = accountFactory.createAccount(_publicAddress2, 222);
        _account3 = accountFactory.createAccount(_publicAddress3, 333);
        _account4 = accountFactory.createAccount(_publicAddress4, 444);

        //deploy test contracts
        _testAggregator = new TestAggregator();
        _testAggregationAccount = new TestAggregationAccount(_entryPoint, _testAggregator);
        _testAggregationAccount2 = new TestAggregationAccount(_entryPoint, _testAggregator);
        _testERC20 = new TestERC20();
        _testWrappedNativeToken = new TestWrappedNativeToken();
        _testUniswap = new TestUniswap(_testWrappedNativeToken);
        _solverUtils = new SolverUtils(_testUniswap, _testERC20, _testWrappedNativeToken);
        _failingStandard = new FailingStandard();
        _failingStdId = _entryPoint.registerIntentStandard(_failingStandard);
        _token = address(_testERC20);

        //set token approvals for accounts to act as proxies to the signing EOAs
        _testERC20.approveFor(_publicAddress, address(_account), 2 ** 256 - 1);
        _testERC20.approveFor(_publicAddress2, address(_account2), 2 ** 256 - 1);
        _testERC20.approveFor(_publicAddress3, address(_account3), 2 ** 256 - 1);
        _testERC20.approveFor(_publicAddress4, address(_account4), 2 ** 256 - 1);

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
     * Private helper function to build call data for the solver to swap tokens and forward some ETH.
     * @param to The address to receive the swapped ETH.
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     * @return The encoded call data for the swap and forward action.
     */
    function _solverSwapERC20ForETHAndForward(address to, uint256 forwardAmount, address forwardTo)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            SolverUtils.swapERC20ForETHAndForward.selector,
            _testUniswap,
            _testERC20,
            _testWrappedNativeToken,
            to,
            forwardAmount,
            forwardTo
        );
    }

    /**
     * Private helper function to build call data for the solver to swap tokens and forward some ETH.
     * @param to The address to receive the swapped ETH.
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     * @return The encoded call data for the swap and forward action.
     */
    function _solverSwapETHForERC20AndForward(address to, uint256 forwardAmount, address forwardTo)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            SolverUtils.swapETHForERC20AndForward.selector,
            _testUniswap,
            _testERC20,
            _testWrappedNativeToken,
            to,
            forwardAmount,
            forwardTo
        );
    }

    /**
     * Private helper function to build a call intent struct for the solver.
     * @return The created UserIntent struct.
     */
    function _solverIntent() internal view returns (UserIntent memory) {
        return IntentBuilder.create(address(_solverUtils));
    }

    /**
     * Private helper function to build a user intent struct.
     * @return The created UserIntent struct.
     */
    function _intent() internal view returns (UserIntent memory) {
        return IntentBuilder.create(address(_account));
    }

    /**
     * Private helper function to build a user intent struct.
     * @return The created UserIntent struct.
     */
    function _intent(uint256 accountIndex) internal view returns (UserIntent memory) {
        return IntentBuilder.create(address(_getAccount(accountIndex)));
    }

    /**
     * Private helper function to build a user intent struct.
     * @return The created UserIntent struct.
     */
    function _intent(address account) internal pure returns (UserIntent memory) {
        return IntentBuilder.create(account);
    }

    function _addErc20Record(UserIntent memory intent, bool isProxy) internal view returns (UserIntent memory) {
        return intent.addSegment(encodeErc20RecordData(ERC20_RECORD_STD_ID, _token, isProxy));
    }

    function _addErc20Release(UserIntent memory intent, int256 amount, bool isProxy)
        internal
        view
        returns (UserIntent memory)
    {
        return intent.addSegment(encodeErc20ReleaseData(ERC20_RELEASE_STD_ID, _token, amount, isProxy));
    }

    function _addErc20ReleaseLinear(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        bool isProxy
    ) internal view returns (UserIntent memory) {
        return intent.addSegment(
            encodeErc20ReleaseComplexData(
                ERC20_RELEASE_STD_ID, _token, startTime, deltaTime, startAmount, deltaAmount, 1, false, isProxy
            )
        );
    }

    function _addErc20ReleaseExponential(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards,
        bool isProxy
    ) internal view returns (UserIntent memory) {
        return intent.addSegment(
            encodeErc20ReleaseComplexData(
                ERC20_RELEASE_STD_ID,
                _token,
                startTime,
                deltaTime,
                startAmount,
                deltaAmount,
                exponent,
                backwards,
                isProxy
            )
        );
    }

    function _addErc20Require(UserIntent memory intent, int256 amount, bool isRelative, bool isProxy)
        internal
        view
        returns (UserIntent memory)
    {
        return intent.addSegment(encodeErc20RequireData(ERC20_REQUIRE_STD_ID, _token, amount, isRelative, isProxy));
    }

    function _addErc20RequireLinear(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        bool isRelative,
        bool isProxy
    ) internal view returns (UserIntent memory) {
        return intent.addSegment(
            encodeErc20RequireComplexData(
                ERC20_REQUIRE_STD_ID,
                _token,
                startTime,
                deltaTime,
                startAmount,
                deltaAmount,
                1,
                false,
                isRelative,
                isProxy
            )
        );
    }

    function _addErc20RequireExponential(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards,
        bool isRelative,
        bool isProxy
    ) internal view returns (UserIntent memory) {
        return intent.addSegment(
            encodeErc20RequireComplexData(
                ERC20_REQUIRE_STD_ID,
                _token,
                startTime,
                deltaTime,
                startAmount,
                deltaAmount,
                exponent,
                backwards,
                isRelative,
                isProxy
            )
        );
    }

    function _addEthRecord(UserIntent memory intent, bool isProxy) internal pure returns (UserIntent memory) {
        return intent.addSegment(encodeEthRecordData(ETH_RECORD_STD_ID, isProxy));
    }

    function _addEthRelease(UserIntent memory intent, int256 amount) internal pure returns (UserIntent memory) {
        return intent.addSegment(encodeEthReleaseData(ETH_RELEASE_STD_ID, amount));
    }

    function _addEthReleaseLinear(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount
    ) internal pure returns (UserIntent memory) {
        return intent.addSegment(
            encodeEthReleaseComplexData(ETH_RELEASE_STD_ID, startTime, deltaTime, startAmount, deltaAmount, 1, false)
        );
    }

    function _addEthReleaseExponential(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards
    ) internal pure returns (UserIntent memory) {
        return intent.addSegment(
            encodeEthReleaseComplexData(
                ETH_RELEASE_STD_ID, startTime, deltaTime, startAmount, deltaAmount, exponent, backwards
            )
        );
    }

    function _addEthRequire(UserIntent memory intent, int256 amount, bool isRelative, bool isProxy)
        internal
        pure
        returns (UserIntent memory)
    {
        return intent.addSegment(encodeEthRequireData(ETH_REQUIRE_STD_ID, amount, isRelative, isProxy));
    }

    function _addEthRequireLinear(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        bool isRelative,
        bool isProxy
    ) internal pure returns (UserIntent memory) {
        return intent.addSegment(
            encodeEthRequireComplexData(
                ETH_REQUIRE_STD_ID, startTime, deltaTime, startAmount, deltaAmount, 1, false, isRelative, isProxy
            )
        );
    }

    function _addEthRequireExponential(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount,
        uint8 exponent,
        bool backwards,
        bool isRelative,
        bool isProxy
    ) internal pure returns (UserIntent memory) {
        return intent.addSegment(
            encodeEthRequireComplexData(
                ETH_REQUIRE_STD_ID,
                startTime,
                deltaTime,
                startAmount,
                deltaAmount,
                exponent,
                backwards,
                isRelative,
                isProxy
            )
        );
    }

    function _addSequentialNonce(UserIntent memory intent, uint256 nonce) internal pure returns (UserIntent memory) {
        return intent.addSegment(encodeSequentialNonceData(SEQUENTIAL_NONCE_STD_ID, nonce));
    }

    function _addSimpleCall(UserIntent memory intent, bytes memory callData)
        internal
        pure
        returns (UserIntent memory)
    {
        return intent.addSegment(encodeSimpleCallData(SIMPLE_CALL_STD_ID, callData));
    }

    function _addUserOp(UserIntent memory intent, uint32 callGasLimit, bytes memory callData)
        internal
        pure
        returns (UserIntent memory)
    {
        return intent.addSegment(encodeUserOperationData(USER_OPERATION_STD_ID, callGasLimit, callData));
    }

    function _addFailingStandard(UserIntent memory intent, bool withReason, bool forContextData)
        internal
        view
        returns (UserIntent memory)
    {
        if (forContextData) return intent.addSegment(abi.encodePacked(_failingStdId, uint256(123)));
        if (withReason) return intent.addSegment(abi.encodePacked(_failingStdId, bytes1(0)));
        return intent.addSegment(abi.encodePacked(_failingStdId));
    }

    function _useRegisteredStandards(UserIntent memory intent) internal view returns (UserIntent memory) {
        for (uint256 i = 0; i < intent.intentData.length; i++) {
            bytes memory data = intent.intentData[i];
            bytes32 stdId;
            assembly {
                stdId := mload(add(32, data))
            }
            if (stdId == SIMPLE_CALL_STD_ID) stdId = bytes32(_simpleCallStdId);
            else if (stdId == ERC20_RECORD_STD_ID) stdId = bytes32(_erc20RecordStdId);
            else if (stdId == ERC20_RELEASE_STD_ID) stdId = bytes32(_erc20ReleaseStdId);
            else if (stdId == ERC20_REQUIRE_STD_ID) stdId = bytes32(_erc20RequireStdId);
            else if (stdId == ETH_RECORD_STD_ID) stdId = bytes32(_ethRecordStdId);
            else if (stdId == ETH_RELEASE_STD_ID) stdId = bytes32(_ethReleaseStdId);
            else if (stdId == ETH_REQUIRE_STD_ID) stdId = bytes32(_ethRequireStdId);
            else if (stdId == SEQUENTIAL_NONCE_STD_ID) stdId = bytes32(_sequentialNonceStdId);
            else if (stdId == USER_OPERATION_STD_ID) stdId = bytes32(_userOperationStdId);
            assembly {
                mstore(add(32, data), stdId)
            }
        }
        return intent;
    }

    /**
     * Private helper function to build an intent solution struct.
     * @param intent First intent that's part of the solution.
     * @return The created IntentSolution struct.
     */
    function _solution(UserIntent memory intent) internal view returns (IntentSolution memory) {
        UserIntent[] memory intents = new UserIntent[](1);
        intents[0] = intent;

        uint256 len = intent.intentData.length;
        uint256[] memory order = new uint256[](len);
        uint256 index = 0;
        while (len > 0) {
            if (len > 0) {
                order[index] = 0;
                len--;
                index++;
            }
        }

        return IntentSolution({timestamp: block.timestamp, intents: intents, order: order});
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

        uint256 len1 = intent1.intentData.length;
        uint256 len2 = intent2.intentData.length;
        uint256[] memory order = new uint256[](len1 + len2);
        uint256 index = 0;
        while (len1 > 0 || len2 > 0) {
            if (len1 > 0) {
                order[index] = 0;
                len1--;
                index++;
            }
            if (len2 > 0) {
                order[index] = 1;
                len2--;
                index++;
            }
        }

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
        uint256 privateKey = _getPrivateKeyBySender(intent.sender);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
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
     * Private helper function to get an account.
     * @param accountIndex The index of the account.
     * @return The account.
     */
    function _getAccount(uint256 accountIndex) internal view returns (address) {
        if (accountIndex == 1) return address(_account2);
        if (accountIndex == 2) return address(_account3);
        if (accountIndex == 3) return address(_account4);
        return address(_account);
    }

    /**
     * Private helper function to get the private key for a sender.
     * @param sender The sender address.
     * @return The account.
     */
    function _getPrivateKeyBySender(address sender) internal view returns (uint256) {
        if (sender == address(_account2)) return _privateKey2;
        if (sender == address(_account3)) return _privateKey3;
        if (sender == address(_account4)) return _privateKey4;
        return _privateKey;
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
     * Private helper function to get bytes (usefule for analyzing segment data).
     * @param data The data to pull from.
     * @param from The start index.
     * @param to The end index.
     * @return result the bytes.
     */
    function _getBytes(bytes memory data, uint256 from, uint256 to) internal pure returns (bytes32 result) {
        result = bytes32(0);
        for (uint256 i = from; i < to; i++) {
            result = (result << 8) | (bytes32(data[i]) >> (31 * 8));
        }
        result = result << ((32 - (to - from)) * 8);
    }
}
