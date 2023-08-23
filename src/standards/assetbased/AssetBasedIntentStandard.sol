// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {IAssetRelease, encodeReleaseAsset} from "./IAssetRelease.sol";
import {IIntentStandard} from "../../interfaces/IIntentStandard.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../../interfaces/IIntentDelegate.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {Exec, RevertReason} from "../../utils/Exec.sol";
import {AssetType, _balanceOf, _transfer} from "./utils/AssetWrapper.sol";
import {AssetHolderProxy} from "./AssetHolderProxy.sol";
import {AssetBasedIntentSegment, parseAssetBasedIntentSegment} from "./AssetBasedIntentSegment.sol";
import {AssetBasedIntentCurve, EvaluationType, AssetBasedIntentCurveLib} from "./AssetBasedIntentCurve.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract AssetBasedIntentStandard is AssetHolderProxy, IAssetRelease, IIntentStandard {
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;
    using UserIntentLib for UserIntent;
    using RevertReason for bytes;

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
     * Release the given token(s) (both fungible and non-fungible)
     *
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param to the target to release tokens to.
     * @param amount the amount to release.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external
    {
        require(_balanceOf(assetType, assetContract, assetId, address(this)) >= amount, "insufficient release balance");
        _transfer(assetType, assetContract, assetId, address(this), to, amount);
    }

    /**
     * Validate intent structure (typically just formatting)
     * @param intent the intent that is about to be solved.
     */
    function validateUserIntent(UserIntent calldata intent) external pure {
        // check over the first data segment first
        if (intent.intentData.length > 0) {
            AssetBasedIntentSegment calldata segment = parseAssetBasedIntentSegment(intent, 0);
            for (uint256 i = 0; i < segment.assetRequirements.length; i++) {
                require(
                    !segment.assetRequirements[i].isRelativeEvaluation(),
                    "relative requirements not allowed at beginning of intent"
                );
                segment.assetRequirements[i].validate();
            }
            for (uint256 i = 0; i < segment.assetReleases.length; i++) {
                segment.assetReleases[i].validate();
            }
        }

        // check through remaining data segments
        for (uint256 j = 1; j < intent.intentData.length; j++) {
            AssetBasedIntentSegment calldata segment = parseAssetBasedIntentSegment(intent, j);
            for (uint256 i = 0; i < segment.assetRequirements.length; i++) {
                segment.assetRequirements[i].validate();
            }
            for (uint256 i = 0; i < segment.assetReleases.length; i++) {
                segment.assetReleases[i].validate();
            }
        }
    }

    /**
     * Performs part or all of the execution for an intent.
     * @param intent the intent to execute.
     * @param dataIndex the data index to execute for.
     * @param timestamp the time at which to evaluate the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution (no data means execution has finished).
     */
    function executeUserIntent(UserIntent calldata intent, uint256 dataIndex, uint256 timestamp, bytes memory context)
        external
        onlyFromEntryPoint
        returns (bytes memory)
    {
        uint256[] memory startingBalances;
        if (context.length > 0) {
            (startingBalances) = abi.decode(context, (uint256[]));
        }
        uint256 evaluateAt = 0;
        if (timestamp > intent.timestamp) {
            evaluateAt = timestamp - intent.timestamp;
        }
        AssetBasedIntentSegment calldata dataSegment = parseAssetBasedIntentSegment(intent, dataIndex);

        //check asset requirements
        _checkAssetRequirements(dataSegment, dataIndex, evaluateAt, startingBalances, intent.sender);

        //record balances for relative requirements later
        if ((dataIndex + 1) < intent.intentData.length) {
            AssetBasedIntentSegment calldata nextDataSegment = parseAssetBasedIntentSegment(intent, dataIndex + 1);
            startingBalances = _recordStartingBalances(nextDataSegment, intent.sender);
        }

        //execute calldata
        if (dataSegment.callData.length > 0) {
            Exec.callAndRevert(intent.sender, dataSegment.callData, dataSegment.callGasLimit, REVERT_REASON_MAX_LEN);
        }

        //release tokens
        _releaseAssets(dataSegment, evaluateAt, intent.sender);

        // return list of starting balances for reference later (or nothing if this was the last step)
        if ((dataIndex + 1) < intent.intentData.length) {
            return abi.encode(startingBalances);
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
                bytes memory data =
                    encodeReleaseAsset(intentSegment.assetReleases[i], address(this), uint256(releaseAmount));
                IIntentDelegate(address(from)).generalizedIntentDelegateCall(data);
            }
        }
    }
}
