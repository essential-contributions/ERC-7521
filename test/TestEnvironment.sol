// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import "../src/core/EntryPoint.sol";
import "../src/standards/assetbased/AssetBasedIntentCurve.sol";
import "../src/standards/assetbased/AssetBasedIntentData.sol";
import "../src/interfaces/UserIntent.sol";
import "../src/wallet/AbstractAccount.sol";
import "./AssetBasedIntentBuilder.sol";

abstract contract TestEnvironment is Test {
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    AssetBasedIntentStandard internal _intentStandard;
    AbstractAccount internal _account;

    address internal _publicAddress = _getPublicAddress(uint256(keccak256("account_private_key")));

    function setUp() public virtual {
        _entryPoint = new EntryPoint();
        _intentStandard = new AssetBasedIntentStandard(_entryPoint);
        _account = new AbstractAccount(_entryPoint, _publicAddress);
    }

    function _curveETH(int256[] memory curveParams, EvaluationType evaluation)
        internal
        pure
        returns (AssetBasedIntentCurve memory)
    {
        AssetBasedIntentCurve memory curve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: AssetBasedIntentBuilder.getCurveType(curveParams),
            evaluationType: evaluation,
            params: curveParams
        });
        return curve;
    }

    function _data() internal pure returns (AssetBasedIntentData memory) {
        AssetBasedIntentCurve memory constantETHCurve = _curveETH(constantCurve(10), EvaluationType.ABSOLUTE);
        AssetBasedIntentCurve memory linearETHCurve = _curveETH(linearCurve(2, 10, 20, false), EvaluationType.ABSOLUTE);

        AssetBasedIntentCurve[] memory assetReleases = new AssetBasedIntentCurve[](2);
        AssetBasedIntentCurve[] memory assetConstraints = new AssetBasedIntentCurve[](2);

        assetReleases[0] = constantETHCurve;
        assetReleases[1] = linearETHCurve;
        assetConstraints[0] = linearETHCurve;
        assetConstraints[1] = constantETHCurve;

        AssetBasedIntentData memory data = AssetBasedIntentData({
            callGasLimit1: 1000000,
            callGasLimit2: 1000000,
            callData1: "calldata 1",
            callData2: "calldata 2",
            assetReleases: assetReleases,
            assetConstraints: assetConstraints
        });

        return data;
    }

    function _intent() internal view returns (UserIntent memory) {
        UserIntent memory intent = UserIntent({
            standard: _intentStandard.standardId(),
            sender: address(_account),
            nonce: 123,
            timestamp: block.timestamp,
            verificationGasLimit: 1000000,
            intentData: "",
            signature: ""
        });
        return AssetBasedIntentBuilder.encodeData(intent, _data());
    }

    function _getPublicAddress(uint256 privateKey) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked("test data"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return ecrecover(digest, v, r, s);
    }
}
