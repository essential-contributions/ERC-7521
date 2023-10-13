// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import {IntentBuilder} from "./IntentBuilder.sol";
import {
    EthReleaseIntentBuilder,
    EthReleaseIntentSegmentBuilder,
    EthReleaseIntentCurveBuilder
} from "./EthReleaseIntentBuilder.sol";
import {
    EthRequireIntentBuilder,
    EthRequireIntentSegmentBuilder,
    EthRequireIntentCurveBuilder
} from "./EthRequireIntentBuilder.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {IIntentStandard} from "../../../src/interfaces/IIntentStandard.sol";
import {UserIntent, UserIntentLib} from "../../../src/interfaces/UserIntent.sol";
import {CallIntentStandard, CallIntentSegment} from "../../../src/standards/call/CallIntentStandard.sol";
import {
    EthReleaseIntentStandard,
    EthReleaseIntentSegment
} from "../../../src/standards/ethRelease/EthReleaseIntentStandard.sol";
import {
    EthRequireIntentStandard,
    EthRequireIntentSegment
} from "../../../src/standards/ethRequire/EthRequireIntentStandard.sol";
import {AbstractAccount} from "../../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

abstract contract TestEnvironment is Test {
    using UserIntentLib for UserIntent;
    using EthReleaseIntentSegmentBuilder for EthReleaseIntentSegment;
    using EthRequireIntentSegmentBuilder for EthRequireIntentSegment;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    CallIntentStandard internal _callIntentStandard;
    EthReleaseIntentStandard internal _ethReleaseIntentStandard;
    EthRequireIntentStandard internal _ethRequireIntentStandard;
    AbstractAccount internal _account;

    address internal _publicAddress = _getPublicAddress(uint256(keccak256("account_private_key")));

    function setUp() public virtual {
        _entryPoint = new EntryPoint();
        _callIntentStandard = new CallIntentStandard(_entryPoint);
        _ethReleaseIntentStandard = new EthReleaseIntentStandard(_entryPoint);
        _ethRequireIntentStandard = new EthRequireIntentStandard(_entryPoint);
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //register intent standards to entry point
        _entryPoint.registerIntentStandard(_callIntentStandard);
        _entryPoint.registerIntentStandard(_ethReleaseIntentStandard);
        _entryPoint.registerIntentStandard(_ethRequireIntentStandard);
    }

    function _intent() internal view returns (UserIntent memory) {
        UserIntent memory intent = IntentBuilder.create(address(_account), 0, block.timestamp);
        intent = EthReleaseIntentBuilder.addSegment(
            intent,
            _ethReleaseIntentStandard.standardId(),
            EthReleaseIntentSegmentBuilder.create().releaseETH(
                EthReleaseIntentCurveBuilder.linearCurve(2, 10, 20, false)
            )
        );
        intent = EthRequireIntentBuilder.addSegment(
            intent,
            _ethRequireIntentStandard.standardId(),
            EthRequireIntentSegmentBuilder.create().requireETH(EthRequireIntentCurveBuilder.constantCurve(10), false)
        );

        return intent;
    }

    function _getPublicAddress(uint256 privateKey) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked("test data"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return ecrecover(digest, v, r, s);
    }

    function test_nothing() public {}
}
