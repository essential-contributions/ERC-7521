// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import {
    AssetBasedIntentBuilder,
    AssetBasedIntentCurveBuilder,
    AssetBasedIntentSegmentBuilder
} from "./AssetBasedIntentBuilder.sol";
import {EntryPoint} from "../../../src/core/EntryPoint.sol";
import {IIntentStandard} from "../../../src/interfaces/IIntentStandard.sol";
import {UserIntent, UserIntentLib} from "../../../src/interfaces/UserIntent.sol";
import {
    AssetBasedIntentCurve,
    generateFlags,
    CurveType,
    EvaluationType
} from "../../../src/standards/assetbased/AssetBasedIntentCurve.sol";
import {
    AssetBasedIntentStandard,
    AssetBasedIntentSegment
} from "../../../src/standards/assetbased/AssetBasedIntentStandard.sol";
import {AssetType} from "../../../src/standards/assetbased/utils/AssetWrapper.sol";
import {AbstractAccount} from "../../../src/wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

abstract contract TestEnvironment is Test {
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    AssetBasedIntentStandard internal _assetBasedIntentStandard;
    AbstractAccount internal _account;

    address internal _publicAddress = _getPublicAddress(uint256(keccak256("account_private_key")));

    function setUp() public virtual {
        _entryPoint = new EntryPoint();
        _assetBasedIntentStandard = new AssetBasedIntentStandard(_entryPoint);
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        //register asset based intent standard to entry point
        _entryPoint.registerIntentStandard(_assetBasedIntentStandard);
    }

    function _curveETH(int256[] memory curveParams, EvaluationType evaluation)
        internal
        pure
        returns (AssetBasedIntentCurve memory)
    {
        AssetBasedIntentCurve memory curve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            flags: generateFlags(AssetType.ETH, AssetBasedIntentSegmentBuilder.getCurveType(curveParams), evaluation),
            params: curveParams
        });
        return curve;
    }

    function _data() internal pure returns (AssetBasedIntentSegment[] memory) {
        AssetBasedIntentSegment[] memory intentSegments = new AssetBasedIntentSegment[](2);

        AssetBasedIntentCurve memory constantETHCurve =
            _curveETH(AssetBasedIntentCurveBuilder.constantCurve(10), EvaluationType.ABSOLUTE);
        AssetBasedIntentCurve memory linearETHCurve =
            _curveETH(AssetBasedIntentCurveBuilder.linearCurve(2, 10, 20, false), EvaluationType.ABSOLUTE);

        AssetBasedIntentCurve[] memory assetReleases = new AssetBasedIntentCurve[](2);
        AssetBasedIntentCurve[] memory assetRequirements = new AssetBasedIntentCurve[](2);

        assetReleases[0] = constantETHCurve;
        assetReleases[1] = linearETHCurve;
        assetRequirements[0] = linearETHCurve;
        assetRequirements[1] = constantETHCurve;

        intentSegments[0].callData = "call data";
        intentSegments[0].assetReleases = assetReleases;
        intentSegments[1].assetRequirements = assetRequirements;

        return intentSegments;
    }

    function _intent() internal view returns (UserIntent memory) {
        bytes32[] memory standards = new bytes32[](1);
        standards[0] = _assetBasedIntentStandard.standardId();
        bytes[] memory data;

        UserIntent memory intent = UserIntent({
            standards: standards,
            sender: address(_account),
            nonce: 123,
            timestamp: block.timestamp,
            intentData: data,
            signature: ""
        });
        return AssetBasedIntentBuilder.encodeData(intent, _data());
    }

    function _getPublicAddress(uint256 privateKey) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked("test data"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return ecrecover(digest, v, r, s);
    }

    function test_nothing() public {}
}
