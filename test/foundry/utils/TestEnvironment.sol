// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../../src/interfaces/UserIntent.sol";
import {IntentBuilder} from "./IntentBuilder.sol";
import {EthRelease, encodeEthReleaseComplexData} from "../../../src/standards/EthRelease.sol";
import {ETH_RELEASE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {EthRequire, encodeEthRequireData} from "../../../src/standards/EthRequire.sol";
import {ETH_REQUIRE_STD_ID} from "../../../src/core/EntryPoint.sol";
import {SimpleCall} from "../../../src/standards/SimpleCall.sol";
import {SimpleAccountFactory} from "../../../src/samples/SimpleAccountFactory.sol";
import {SimpleAccount} from "../../../src/samples/SimpleAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

abstract contract TestEnvironment is Test {
    using IntentBuilder for UserIntent;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    EthRelease internal _ethRelease;
    EthRequire internal _ethRequire;
    SimpleCall internal _simpleCall;
    SimpleAccount internal _account;

    address internal _publicAddress = _getPublicAddress(uint256(keccak256("account_private_key")));

    function setUp() public virtual {
        _entryPoint = new EntryPoint();
        _simpleCall = new SimpleCall();
        _ethRequire = new EthRequire();
        _ethRelease = new EthRelease();

        //deploy contracts
        SimpleAccountFactory accountFactory = new SimpleAccountFactory(_entryPoint);
        _account = accountFactory.createAccount(_publicAddress, 0);

        //register intent standards to entry point
        _entryPoint.registerIntentStandard(_ethRelease);
    }

    function _intent() internal view returns (UserIntent memory) {
        UserIntent memory intent = IntentBuilder.create(address(_account));
        intent = _addEthRelease(intent, uint32(block.timestamp), 20, 10, 2);
        intent = _addEthRequire(intent, 10, false);

        return intent;
    }

    function _addEthRelease(
        UserIntent memory intent,
        uint32 startTime,
        uint16 deltaTime,
        int256 startAmount,
        int256 deltaAmount
    ) internal pure returns (UserIntent memory) {
        return intent.addSegment(
            encodeEthReleaseComplexData(ETH_RELEASE_STD_ID, startTime, deltaTime, startAmount, deltaAmount, 0, false)
        );
    }

    function _addEthRequire(UserIntent memory intent, int256 amount, bool isRelative)
        internal
        pure
        returns (UserIntent memory)
    {
        return intent.addSegment(encodeEthRequireData(ETH_REQUIRE_STD_ID, amount, isRelative, false));
    }

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
