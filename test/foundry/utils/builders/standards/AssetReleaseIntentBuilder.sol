// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {UserIntent} from "../../../../../src/interfaces/UserIntent.sol";
import {CurveBuilder} from "../CurveBuilder.sol";
import {AssetCurve, generateAssetFlags, EvaluationType} from "../../../../../src/utils/curves/AssetCurve.sol";
import {
    AssetReleaseIntentStandard,
    AssetReleaseIntentSegment
} from "../../../../../src/standards/AssetReleaseIntentStandard.sol";
import {AssetType} from "../../../../../src/utils/wrappers/AssetWrapper.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title AssetReleaseIntentBuilder
 * Utility functions helpful for building an asset release intent.
 */
library AssetReleaseIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param standard The standard ID for the intent segment.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes32 standard, AssetReleaseIntentSegment memory segment)
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
     * Encodes the asset release intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The asset release intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, AssetReleaseIntentSegment memory segment)
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
     * Decodes the asset release intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The asset release intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (AssetReleaseIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        AssetReleaseIntentSegment memory decoded = abi.decode(raw, (AssetReleaseIntentSegment));
        return decoded;
    }

    function testNothing() public {}
}

/**
 * @title AssetReleaseIntentSegmentBuilder
 * Utility functions helpful for building an asset release intent segment.
 */
library AssetReleaseIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @return intent The created user intent segment.
     */
    function create() public pure returns (AssetReleaseIntentSegment memory) {
        AssetCurve memory assetRelease;

        return AssetReleaseIntentSegment({assetRelease: assetRelease});
    }

    /**
     * Add an asset release for ERC721 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC721 token contract.
     * @param id The ID of the ERC721 token.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent segment.
     */
    function releaseERC721(AssetReleaseIntentSegment memory segment, address addr, uint256 id, int256[] memory curve)
        public
        pure
        returns (AssetReleaseIntentSegment memory)
    {
        return _addAssetRelCurve(segment, addr, id, AssetType.ERC721, curve);
    }

    /**
     * Add an asset release for ERC1155 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC1155 token contract.
     * @param id The ID of the ERC1155 token.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent segment.
     */
    function releaseERC1155(AssetReleaseIntentSegment memory segment, address addr, uint256 id, int256[] memory curve)
        public
        pure
        returns (AssetReleaseIntentSegment memory)
    {
        return _addAssetRelCurve(segment, addr, id, AssetType.ERC1155, curve);
    }

    /**
     * Private helper function to add an asset release curve to a user intent segment.
     */
    function _addAssetRelCurve(
        AssetReleaseIntentSegment memory segment,
        address assetContract,
        uint256 assetId,
        AssetType assetType,
        int256[] memory curveParams
    ) private pure returns (AssetReleaseIntentSegment memory) {
        segment.assetRelease = AssetCurve({
            assetContract: assetContract,
            assetId: assetId,
            flags: generateAssetFlags(assetType, CurveBuilder.getCurveType(curveParams), EvaluationType.ABSOLUTE),
            params: curveParams
        });

        return segment;
    }

    function testNothing() public {}
}
