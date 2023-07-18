// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {IIntentStandard} from "../../interfaces/IIntentStandard.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {Exec} from "../../utils/Exec.sol";
import {_balanceOf} from "./utils/AssetWrapper.sol";
import {IAssetRelease} from "./IAssetRelease.sol";
import {AssetHolderProxy} from "./AssetHolderProxy.sol";
import {AssetBasedIntentData, parseAssetBasedIntentData, AssetBasedIntentDataLib} from "./AssetBasedIntentData.sol";
import {AssetBasedIntentCurve, EvaluationType, AssetBasedIntentCurveLib} from "./AssetBasedIntentCurve.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract AssetBasedIntentStandard is AssetHolderProxy, IIntentStandard {
    using AssetBasedIntentDataLib for AssetBasedIntentData;
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;
    using UserIntentLib for UserIntent;

    /**
     * Basic state and constants.
     */
    IEntryPoint private immutable _entryPoint;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Contract constructor.
     * @param entryPoint the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPoint) {
        _entryPoint = entryPoint;
        entryPoint.registerIntentStandard(this);
    }

    /**
     * Default receive function.
     */
    receive() external payable {}

    /////////////////////////
    // DELEGATE/PURE CALLS //
    /////////////////////////

    /**
     * Validate intent structure (typically just formatting)
     * @param userInt the intent that is about to be solved.
     */
    function validateUserInt(UserIntent calldata userInt) external pure {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);
        data.validate();
    }

    function executeFirstPass(UserIntent calldata userInt, uint256 timestamp)
        external
        returns (bytes memory endContext)
    {
        IEntryPoint entryPoint = IEntryPoint(address(this));
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);

        //record starting balances
        uint256 constraintLen = data.assetConstraints.length;
        uint256[] memory startingBalances = new uint256[](constraintLen);
        for (uint256 i = 0; i < constraintLen; i++) {
            if (data.assetConstraints[i].evaluationType == EvaluationType.RELATIVE) {
                startingBalances[i] = _balanceOf(
                    data.assetConstraints[i].assetType,
                    data.assetConstraints[i].assetContract,
                    data.assetConstraints[i].assetId,
                    userInt.sender
                );
            }
        }

        //execute
        if (data.callData1.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData1, data.callGasLimit1, REVERT_REASON_MAX_LEN);
        }

        //release tokens
        address releaseTo = address(entryPoint.getIntentStandardContract(userInt.getStandard()));
        uint256 evaluateAt = 0;
        if (timestamp > userInt.timestamp) {
            evaluateAt = timestamp - userInt.timestamp;
        }
        for (uint256 i = 0; i < data.assetReleases.length; i++) {
            int256 releaseAmount = data.assetReleases[i].evaluate(evaluateAt);
            if (releaseAmount < 0) releaseAmount = 0;
            IAssetRelease(userInt.sender).releaseAsset(
                data.assetReleases[i].assetType,
                data.assetReleases[i].assetContract,
                data.assetReleases[i].assetId,
                releaseTo,
                uint256(releaseAmount)
            );
        }

        // return list of starting balances for reference later
        return abi.encode(startingBalances);
    }

    // solhint-disable-next-line no-unused-vars
    function executeSecondPass(UserIntent calldata userInt, uint256 timestamp, bytes memory context)
        external
        returns (bytes memory endContext)
    {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);

        //execute
        if (data.callData2.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData2, data.callGasLimit2, REVERT_REASON_MAX_LEN);
        }

        //return unchanged context
        return context;
    }

    function verifyEndState(UserIntent calldata userInt, uint256 timestamp, bytes memory context) external view {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);
        uint256[] memory startingBalances = abi.decode(context, (uint256[]));

        //check end balances
        uint256 evaluateAt = 0;
        if (timestamp > userInt.timestamp) {
            evaluateAt = timestamp - userInt.timestamp;
        }
        for (uint256 i = 0; i < data.assetConstraints.length; i++) {
            int256 requiredBalance = data.assetConstraints[i].evaluate(evaluateAt);
            if (data.assetConstraints[i].evaluationType == EvaluationType.RELATIVE) {
                requiredBalance = int256(startingBalances[i]) + requiredBalance;
                if (requiredBalance < 0) requiredBalance = 0;
            }

            uint256 currentBalance = _balanceOf(
                data.assetConstraints[i].assetType,
                data.assetConstraints[i].assetContract,
                data.assetConstraints[i].assetId,
                userInt.sender
            );
            require(
                currentBalance >= uint256(requiredBalance),
                string.concat(
                    "insufficient balance (required: ",
                    Strings.toString(requiredBalance),
                    ", current: ",
                    Strings.toString(currentBalance),
                    ")"
                )
            );
        }
    }
}
