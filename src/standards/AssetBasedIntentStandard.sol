// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IAssetRelease} from "../interfaces/IAssetRelease.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";
import {AssetBasedIntentData, AssetBasedIntentDataLib} from "./AssetBasedIntentData.sol";
import {AssetCurve, EvaluationType, AssetCurveLib} from "./AssetCurve.sol";
import {AssetWrapper} from "./AssetWrapper.sol";

contract AssetBasedIntentStandard is IIntentStandard {
    using AssetBasedIntentDataLib for AssetBasedIntentData;
    using AssetCurveLib for AssetCurve;
    using AssetWrapper for AssetCurve;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Validate intent structure (typically just formatting)
     * the entryPoint will continue to execute an intent solution only if this validation call returns successfully.
     * This allows making a "simulation call" without valid timings, etc
     * Other failures (e.g. invalid format) should still revert to signal failure.
     *
     * @param userInt the intent that is about to be solved.
     * @return validationData packaged ValidationData structure. use `_packValidationData` and `_unpackValidationData` to encode and decode
     *      <20-byte> reserved - currently not used (fill with zeroes)
     *      <6-byte> validUntil - last timestamp this intent is valid. 0 for "indefinite"
     *      <6-byte> validAfter - first timestamp this intent is valid
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function validateUserInt(UserIntent calldata userInt) external pure returns (uint256 validationData) {
        AssetBasedIntentData memory data = AssetBasedIntentDataLib.parse(userInt);

        //validate constraint curves
        for(uint256 i=0; i<data.assetConstraints.length; i++) {
            data.assetConstraints[i].validate();
        }

        //validate release curves
        for(uint256 i=0; i<data.assetReleases.length; i++) {
            data.assetReleases[i].validate();
        }

        //determine valid time window
        uint48 validUntil = 0;
        uint48 validAfter = uint48(data.timestamp);
        validationData = (uint256(validUntil) << 160) | (uint256(validAfter) << (160 + 48));
    }

    function executeFirstPass(UserIntent calldata userInt, uint256 timestamp) external returns (bytes memory context) {
        AssetBasedIntentData memory data = AssetBasedIntentDataLib.parse(userInt);

        //record starting balances
        uint256 constraintLen = data.assetConstraints.length;
        uint256[] memory startingBalances = new uint256[](constraintLen);
        for(uint256 i=0; i<constraintLen; i++) {
            if(data.assetConstraints[i].evaluationType == EvaluationType.RELATIVE) {
                startingBalances[i] = data.assetConstraints[i].balanceOf(userInt.sender);
            }
        }

        //execute
        if (data.callData1.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData1, REVERT_REASON_MAX_LEN);
        }

        //release tokens
        for(uint256 i=0; i<data.assetReleases.length; i++) {
            uint256 evaluateAt = timestamp - data.timestamp;
            uint256 releaseAmount = data.assetReleases[i].evaluate(evaluateAt);
            IAssetRelease(userInt.sender).releaseAsset(
                data.assetReleases[i].assetType, 
                data.assetReleases[i].assetContract, 
                data.assetReleases[i].assetId, 
                releaseAmount
            );
        }

        // return list of starting balances for reference later
        return abi.encode(startingBalances);
    }

    function executeSecondPass(UserIntent calldata userInt, uint256 timestamp) external {
        AssetBasedIntentData memory data = AssetBasedIntentDataLib.parse(userInt);

        //execute
        if (data.callData2.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData2, REVERT_REASON_MAX_LEN);
        }
    }

    function verifyEndState(UserIntent calldata userInt, uint256 timestamp, bytes memory context) external {
        AssetBasedIntentData memory data = AssetBasedIntentDataLib.parse(userInt);
        uint256[] memory startingBalances = abi.decode(context, (uint256[]));

        //TODO: implement end state check
    }

    function hash(UserIntent calldata userInt) external pure returns (bytes32) {
        return AssetBasedIntentDataLib.hash(userInt);
    }
}
