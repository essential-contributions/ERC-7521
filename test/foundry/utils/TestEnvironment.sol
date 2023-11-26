// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../../src/interfaces/UserIntent.sol";
import {IntentBuilder} from "./IntentBuilder.sol";
import {EthReleaseLinear} from "../../../src/standards/EthReleaseLinear.sol";
import {EthRequire} from "../../../src/standards/EthRequire.sol";
import {SimpleCall} from "../../../src/standards/SimpleCall.sol";
import {AbstractAccount} from "../../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

abstract contract TestEnvironment is Test {
    using IntentBuilder for UserIntent;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    EthReleaseLinear internal _ethReleaseLinear;
    EthRequire internal _ethRequire;
    SimpleCall internal _simpleCall;
    AbstractAccount internal _account;

    address internal _publicAddress = _getPublicAddress(uint256(keccak256("account_private_key")));

    function setUp() public virtual {
        _entryPoint = new EntryPoint();
        _simpleCall = SimpleCall(_entryPoint);
        _ethReleaseLinear = new EthReleaseLinear();
        _ethRequire = new EthRequire();
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //register intent standards to entry point
        _entryPoint.registerIntentStandard(_ethReleaseLinear);
        _entryPoint.registerIntentStandard(_ethRequire);
    }

    function _intent() internal view returns (UserIntent memory) {
        UserIntent memory intent = IntentBuilder.create(address(_account));
        intent = _addEthReleaseLinear(intent, uint40(block.timestamp), uint32(20), 10, 2);
        intent = _addEthRequire(intent, 10, false);

        return intent;
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
        bytes32 standardId = _entryPoint.getIntentStandardId(_ethRequire);
        return intent.addSegment(_ethRequire.encodeData(standardId, amount, isRelative));
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
