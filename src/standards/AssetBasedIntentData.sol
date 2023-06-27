// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {AssetCurve, AssetCurveLib} from "./AssetCurve.sol";

/**
 * Asset Based Intent Data struct
 * @param timestamp the time when the intent was created.
 * @param callGasLimit1 max gas to be spent on the first part of intent call data.
 * @param callGasLimit2 max gas to be spent on the second part of intent call data.
 * @param callData1 the first part of the intents desired call data.
 * @param callData2 the second part of the intents desired call data.
 * @param assetRelease list of assets that are released before the solution gets executed.
 * @param assetConstraint list of assets that are required to be owned by the account at the end of the solution execution.
 */
struct AssetBasedIntentData {
    uint256 timestamp;
    uint256 callGasLimit1;
    uint256 callGasLimit2;
    bytes callData1;
    bytes callData2;
    AssetCurve[] assetReleases;
    AssetCurve[] assetConstraints;
}

/**
 * Utility functions helpful when working with AssetBasedIntentData structs.
 */
library AssetBasedIntentDataLib {
    function pack(UserIntent calldata userInt) public pure returns (bytes memory ret) {
        bytes32 standard = UserIntentLib.getStandard(userInt);
        address sender = userInt.sender;
        uint256 nonce = userInt.nonce;
        uint256 verificationGasLimit = userInt.verificationGasLimit;

        //TODO: try to do this packing without copying to memory (take advantgae of calldataKeccak)
        AssetBasedIntentData memory data = parse(userInt);
        uint256 timestamp = data.timestamp;
        uint256 callGasLimit1 = data.callGasLimit1;
        uint256 callGasLimit2 = data.callGasLimit2;
        bytes32 callData1 = keccak256(data.callData1);
        bytes32 callData2 = keccak256(data.callData2);
        bytes32 assetRelease = _hashCurves(data.assetReleases);
        bytes32 assetConstraint = _hashCurves(data.assetConstraints);

        return abi.encode(
            standard, sender, nonce, verificationGasLimit, 
            timestamp, callGasLimit1, callGasLimit2,
            callData1, callData2, assetRelease, assetConstraint
        );
    }

    function hash(UserIntent calldata userInt) public pure returns (bytes32) {
        return keccak256(pack(userInt));
    }

    function parse(UserIntent calldata userInt) public pure returns (AssetBasedIntentData memory ret) {
        (AssetBasedIntentData memory data) = abi.decode(userInt.intentData, (AssetBasedIntentData));
        return data;
    }

    function _hashCurves(AssetCurve[] memory curves) private pure returns (bytes32) {
        bytes32[] memory hashes = new bytes32[](curves.length);
        return keccak256(abi.encodePacked(hashes));
    }
}
