// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "forge-std/Test.sol";
import "../src/core/EntryPoint.sol";
import "../src/standards/assetbased/AssetBasedIntentCurve.sol";
import "../src/standards/assetbased/AssetBasedIntentData.sol";
import "../src/interfaces/UserIntent.sol";

// TODO: move to src/test and possibly separate
abstract contract TestUtil {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;
    using AssetBasedIntentDataLib for AssetBasedIntentData;
    using UserIntentLib for UserIntent;

    bytes32 public constant STANDARD_ID = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    int256[] public constantParams = new int256[](1);
    int256[] public linearParams = new int256[](3);
    int256[] public exponentialParams = new int256[](4);

    AssetBasedIntentCurve[] public assetReleaseCurves;
    AssetBasedIntentCurve[] public assetConstraintCurves;

    AssetBasedIntentCurve public constantAbsoluteCurve;
    AssetBasedIntentCurve public constantRelativeCurve;
    AssetBasedIntentCurve public linearAbsoluteCurve;
    AssetBasedIntentCurve public linearRelativeCurve;
    AssetBasedIntentCurve public exponentialAbsoluteCurve;
    AssetBasedIntentCurve public exponentialRelativeCurve;

    mapping(uint256 => AssetBasedIntentData) public assetBasedIntentDataMap;

    UserIntent public userIntent;

    EntryPoint public entryPoint;

    constructor() {
        constantParams = [int256(10)];
        linearParams = [int256(2), int256(10), int256(20)];
        exponentialParams = [int256(2), int256(10), int256(2), int256(20)];

        constantAbsoluteCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: CurveType.CONSTANT,
            evaluationType: EvaluationType.ABSOLUTE,
            params: constantParams
        });
        constantRelativeCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: CurveType.CONSTANT,
            evaluationType: EvaluationType.RELATIVE,
            params: constantParams
        });
        linearAbsoluteCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: CurveType.LINEAR,
            evaluationType: EvaluationType.ABSOLUTE,
            params: linearParams
        });
        linearRelativeCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: CurveType.LINEAR,
            evaluationType: EvaluationType.RELATIVE,
            params: linearParams
        });
        exponentialAbsoluteCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: CurveType.EXPONENTIAL,
            evaluationType: EvaluationType.ABSOLUTE,
            params: exponentialParams
        });
        exponentialRelativeCurve = AssetBasedIntentCurve({
            assetContract: address(0),
            assetId: 0,
            assetType: AssetType.ETH,
            curveType: CurveType.EXPONENTIAL,
            evaluationType: EvaluationType.RELATIVE,
            params: exponentialParams
        });

        assetReleaseCurves.push(constantAbsoluteCurve);
        assetConstraintCurves.push(constantAbsoluteCurve);

        assetBasedIntentDataMap[0].callGasLimit1 = 100000;
        assetBasedIntentDataMap[0].callGasLimit2 = 100000;
        assetBasedIntentDataMap[0].callData1 = "call data 1"; // TODO: make use of common structs
        assetBasedIntentDataMap[0].callData2 = "call data 2"; // TODO: make use of common structs
        assetBasedIntentDataMap[0].assetReleases = assetReleaseCurves;
        assetBasedIntentDataMap[0].assetConstraints = assetConstraintCurves;

        AssetBasedIntentData memory assetBasedIntentData = assetBasedIntentDataMap[0];

        userIntent = UserIntent({
            standard: STANDARD_ID,
            sender: address(this),
            nonce: 123,
            timestamp: block.timestamp,
            verificationGasLimit: 100000,
            intentData: abi.encode(assetBasedIntentData),
            signature: "signature"
        });

        entryPoint = new EntryPoint();
    }
}
