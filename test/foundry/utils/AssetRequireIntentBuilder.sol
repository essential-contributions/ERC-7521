// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {AssetCurve, generateAssetFlags, CurveType, EvaluationType} from "../../../src/utils/AssetCurve.sol";
import {
    AssetRequireIntentStandard,
    AssetRequireIntentSegment
} from "../../../src/standards/assetRequire/AssetRequireIntentStandard.sol";
import {AssetType} from "../../../src/utils/AssetWrapper.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title AssetRequireIntentBuilder
 * Utility functions helpful for building an asset require intent.
 */
library AssetRequireIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param standard The standard ID for the intent segment.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes32 standard, AssetRequireIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        bytes32[] memory standards = new bytes32[](intent.standards.length + 1);
        for (uint256 i = 0; i < intent.standards.length; i++) {
            standards[i] = intent.standards[i];
        }
        standards[intent.standards.length] = standard;
        intent.standards = standards;

        return encodeData(intent, segment);
    }

    /**
     * Encodes the asset require intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The asset require intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, AssetRequireIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        bytes[] memory intentData = intent.intentData;
        bytes[] memory newData = new bytes[](intentData.length + 1);
        for (uint256 i = 0; i < intentData.length; i++) {
            newData[i] = intentData[i];
        }
        bytes memory raw = abi.encode(segment);
        bytes memory encoded = new bytes(raw.length - 32);
        for (uint256 j = 32; j < raw.length; j++) {
            encoded[j - 32] = raw[j];
        }
        newData[intentData.length] = encoded;
        intent.intentData = newData;

        return intent;
    }

    /**
     * Decodes the asset require intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The asset require intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (AssetRequireIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        AssetRequireIntentSegment memory decoded = abi.decode(raw, (AssetRequireIntentSegment));
        return decoded;
    }
}

/**
 * @title AssetRequireIntentSegmentBuilder
 * Utility functions helpful for building an asset require intent segment.
 */
library AssetRequireIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @return intent The created user intent segment.
     */
    function create() public pure returns (AssetRequireIntentSegment memory) {
        AssetCurve memory assetRequirement;

        return AssetRequireIntentSegment({assetRequirement: assetRequirement});
    }

    /**
     * Internal helper function to determine the type of the curve based on its parameters.
     */
    function getCurveType(int256[] memory params) internal pure returns (CurveType) {
        if (params.length == 4) return CurveType.EXPONENTIAL;
        if (params.length == 3) return CurveType.LINEAR;
        return CurveType.CONSTANT;
    }

    /**
     * Add an end state required asset of ERC20 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC20 token contract.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent segment.
     */
    function requireERC20(AssetRequireIntentSegment memory segment, address addr, int256[] memory curve, bool relative)
        public
        pure
        returns (AssetRequireIntentSegment memory)
    {
        return _addAssetReqCurve(segment, addr, uint256(0), AssetType.ERC20, curve, relative);
    }

    /**
     * Add an end state required asset of ERC721 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC721 token contract.
     * @param id The ID of the ERC721 token.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent segment.
     */
    function requireERC721(
        AssetRequireIntentSegment memory segment,
        address addr,
        uint256 id,
        int256[] memory curve,
        bool relative
    ) public pure returns (AssetRequireIntentSegment memory) {
        return _addAssetReqCurve(segment, addr, id, AssetType.ERC721, curve, relative);
    }

    /**
     * Add an end state required asset of ERC1155 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC1155 token contract.
     * @param id The ID of the ERC1155 token.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent segment.
     */
    function requireERC1155(
        AssetRequireIntentSegment memory segment,
        address addr,
        uint256 id,
        int256[] memory curve,
        bool relative
    ) public pure returns (AssetRequireIntentSegment memory) {
        return _addAssetReqCurve(segment, addr, id, AssetType.ERC1155, curve, relative);
    }

    /**
     * Private helper function to add an asset release curve to a user intent segment.
     */
    function _addAssetReqCurve(
        AssetRequireIntentSegment memory segment,
        address assetContract,
        uint256 assetId,
        AssetType assetType,
        int256[] memory curveParams,
        bool isRelative
    ) private pure returns (AssetRequireIntentSegment memory) {
        //create new curve element
        EvaluationType evalType = EvaluationType.ABSOLUTE;
        if (isRelative) evalType = EvaluationType.RELATIVE;
        segment.assetRequirement = AssetCurve({
            assetContract: assetContract,
            assetId: assetId,
            flags: generateAssetFlags(assetType, getCurveType(curveParams), evalType),
            params: curveParams
        });

        return segment;
    }
}
