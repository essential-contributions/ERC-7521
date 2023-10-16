// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../../../../src/interfaces/UserIntent.sol";
import {EthCurve, generateEthFlags, CurveType, EvaluationType} from "../../../../../src/utils/curves/EthCurve.sol";
import {getCurveType} from "../CurveBuilder.sol";
import {
    EthReleaseIntentStandard,
    EthReleaseIntentSegment
} from "../../../../../src/standards/EthReleaseIntentStandard.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title EthReleaseIntentBuilder
 * Utility functions helpful for building an eth release intent.
 */
library EthReleaseIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param standard The standard ID for the intent segment.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes32 standard, EthReleaseIntentSegment memory segment)
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
     * Encodes the eth release intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The eth release intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, EthReleaseIntentSegment memory segment)
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
     * Decodes the eth release intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The eth release intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (EthReleaseIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        EthReleaseIntentSegment memory decoded = abi.decode(raw, (EthReleaseIntentSegment));
        return decoded;
    }
}

/**
 * @title EthReleaseIntentSegmentBuilder
 * Utility functions helpful for building an eth release intent segment.
 */
library EthReleaseIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @return intent The created user intent segment.
     */
    function create() public pure returns (EthReleaseIntentSegment memory) {
        EthCurve memory release;

        return EthReleaseIntentSegment({release: release});
    }

    /**
     * Private helper function to add an asset release curve to a user intent.
     * Add an asset release for ETH to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent segment.
     */
    function releaseETH(EthReleaseIntentSegment memory segment, int256[] memory curve)
        public
        pure
        returns (EthReleaseIntentSegment memory)
    {
        return _addEthRelCurve(segment, curve);
    }

    /**
     * Private helper function to add an eth release curve to a user intent segment.
     */
    function _addEthRelCurve(EthReleaseIntentSegment memory segment, int256[] memory curveParams)
        private
        pure
        returns (EthReleaseIntentSegment memory)
    {
        segment.release =
            EthCurve({flags: generateEthFlags(getCurveType(curveParams), EvaluationType.ABSOLUTE), params: curveParams});

        return segment;
    }
}
