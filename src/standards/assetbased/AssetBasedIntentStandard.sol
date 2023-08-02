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
import {
    AssetBasedIntentData,
    AssetBasedIntentSegment,
    parseAssetBasedIntentData,
    AssetBasedIntentDataLib
} from "./AssetBasedIntentData.sol";
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
     * @param entryPointContract the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPointContract) {
        _entryPoint = entryPointContract;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function standardId() public view returns (bytes32) {
        return _entryPoint.getIntentStandardId(this);
    }

    /**
     * Default receive function.
     */
    receive() external payable {}

    /**
     * Validate intent structure (typically just formatting)
     * @param userInt the intent that is about to be solved.
     */
    function validateUserInt(UserIntent calldata userInt) external pure {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);
        data.validate();
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param userInt the intent to execute.
     * @param timestamp the time at which to evaluate the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution (no data means execution has finished).
     */
    function executeUserIntent(UserIntent calldata userInt, uint256 timestamp, bytes memory context)
        external
        onlyFromEntryPoint
        returns (bytes memory)
    {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);
        uint256 intentSegmentIndex = 0;
        uint256[] memory startingBalances;
        if (context.length > 0) {
            (intentSegmentIndex, startingBalances) = abi.decode(context, (uint256, uint256[]));
        }
        uint256 evaluateAt = 0;
        if (timestamp > userInt.timestamp) {
            evaluateAt = timestamp - userInt.timestamp;
        }
        AssetBasedIntentSegment calldata intentSegment = data.intentSegments[intentSegmentIndex];

        //check asset requirements
        _checkAssetRequirements(intentSegment, intentSegmentIndex, evaluateAt, startingBalances, userInt.sender);

        //record balances for relative requirements later
        if ((intentSegmentIndex + 1) < data.intentSegments.length) {
            AssetBasedIntentSegment calldata nextIntentSegment = data.intentSegments[intentSegmentIndex + 1];
            startingBalances = _recordStartingBalances(nextIntentSegment, userInt.sender);
        }

        //execute calldata
        if (intentSegment.callData.length > 0) {
            Exec.callAndRevert(
                userInt.sender, intentSegment.callData, intentSegment.callGasLimit, REVERT_REASON_MAX_LEN
            );
        }

        //release tokens
        _releaseAssets(intentSegment, evaluateAt, userInt.sender);

        // return list of starting balances for reference later (or nothing if this was the last step)
        if ((intentSegmentIndex + 1) < data.intentSegments.length) {
            intentSegmentIndex = intentSegmentIndex + 1;
            return abi.encode(intentSegmentIndex, startingBalances);
        }
        return "";
    }

    /**
     * Verifies the intent standard is for a given entry point contract (required for registration on the entry point).
     * @param entryPointContract the entry point contract.
     * @return flag indicating if the intent standard is for the given entry point.
     */
    function isIntentStandardForEntryPoint(IEntryPoint entryPointContract) external view returns (bool) {
        return entryPointContract == _entryPoint;
    }

    /**
     * Checks asset requirements.
     * @param intentSegment The intent segment to check requirements for.
     * @param intentSegmentIndex The index of the intent segment within the intent data.
     * @param evaluateAt The time offset at which to evaluate the asset requirements.
     * @param startingBalances The array of starting balances for relative requirements.
     * @param owner The address of the owner to check requirements for.
     */
    function _checkAssetRequirements(
        AssetBasedIntentSegment calldata intentSegment,
        uint256 intentSegmentIndex,
        uint256 evaluateAt,
        uint256[] memory startingBalances,
        address owner
    ) private view {
        for (uint256 i = 0; i < intentSegment.assetRequirements.length; i++) {
            int256 requiredBalance = intentSegment.assetRequirements[i].evaluate(evaluateAt);
            if (intentSegment.assetRequirements[i].isRelativeEvaluation()) {
                require(intentSegmentIndex > 0, "relative requirements not allowed at beginning of intent");
                requiredBalance = int256(startingBalances[i]) + requiredBalance;
                if (requiredBalance < 0) requiredBalance = 0;
            }
            uint256 currentBalance = _balanceOf(
                intentSegment.assetRequirements[i].assetType(),
                intentSegment.assetRequirements[i].assetContract,
                intentSegment.assetRequirements[i].assetId,
                owner
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

    /**
     * Records balances for relative requirements later.
     * @param nextIntentSegment The next intent segment for which to record starting balances.
     * @param owner The address of the owner whose balances need to be recorded.
     * @return The array of starting balances for relative requirements.
     */
    function _recordStartingBalances(AssetBasedIntentSegment calldata nextIntentSegment, address owner)
        private
        view
        returns (uint256[] memory)
    {
        uint256 requirementsLen = nextIntentSegment.assetRequirements.length;
        uint256[] memory startingBalances = new uint256[](requirementsLen);
        for (uint256 i = 0; i < requirementsLen; i++) {
            if (nextIntentSegment.assetRequirements[i].isRelativeEvaluation()) {
                startingBalances[i] = _balanceOf(
                    nextIntentSegment.assetRequirements[i].assetType(),
                    nextIntentSegment.assetRequirements[i].assetContract,
                    nextIntentSegment.assetRequirements[i].assetId,
                    owner
                );
            }
        }
        return startingBalances;
    }

    /**
     * Release tokens.
     * @param intentSegment The intent segment containing the asset releases.
     * @param evaluateAt The time offset at which to evaluate the asset releases.
     * @param from The address from which to release the assets.
     */
    function _releaseAssets(AssetBasedIntentSegment calldata intentSegment, uint256 evaluateAt, address from) private {
        for (uint256 i = 0; i < intentSegment.assetReleases.length; i++) {
            int256 releaseAmount = intentSegment.assetReleases[i].evaluate(evaluateAt);
            if (releaseAmount > 0) {
                IAssetRelease(from).releaseAsset(
                    intentSegment.assetReleases[i].assetType(),
                    intentSegment.assetReleases[i].assetContract,
                    intentSegment.assetReleases[i].assetId,
                    address(this),
                    uint256(releaseAmount)
                );
            }
        }
    }
}
