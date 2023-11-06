// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {UserIntent} from "../../../../../src/interfaces/UserIntent.sol";
import {EthCurve, CurveType, EvaluationType} from "../../../../../src/utils/curves/EthCurve.sol";
import {generateFlags} from "../../../../../src/utils/Helpers.sol";
import {CurveBuilder} from "../CurveBuilder.sol";
import {
    EthRequireIntentStandard,
    EthRequireIntentSegment
} from "../../../../../src/standards/EthRequireIntentStandard.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title EthRequireIntentBuilder
 * Utility functions helpful for building an eth require intent.
 */
library EthRequireIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, EthRequireIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        return encodeData(intent, segment);
    }

    /**
     * Encodes the eth require intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The eth require intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, EthRequireIntentSegment memory segment)
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
     * Decodes the eth require intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The eth require intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (EthRequireIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        EthRequireIntentSegment memory decoded = abi.decode(raw, (EthRequireIntentSegment));
        return decoded;
    }

    function testNothing() public {}
}

/**
 * @title EthRequireIntentSegmentBuilder
 * Utility functions helpful for building an eth require intent segment.
 */
library EthRequireIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @param standard The standard ID for the intent segment.
     * @return intent The created user intent segment.
     */
    function create(bytes32 standard) public pure returns (EthRequireIntentSegment memory) {
        EthCurve memory requirement;

        return EthRequireIntentSegment({standard: standard, requirement: requirement});
    }

    /**
     * Add an end state required asset of ETH to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent segment.
     */
    function requireEth(EthRequireIntentSegment memory segment, uint48 timestamp, int256[] memory curve, bool relative)
        public
        pure
        returns (EthRequireIntentSegment memory)
    {
        return _addEthReqCurve(segment, timestamp, curve, relative);
    }

    /**
     * Private helper function to add an eth release curve to a user intent segment.
     */
    function _addEthReqCurve(
        EthRequireIntentSegment memory segment,
        uint48 timestamp,
        int256[] memory curveParams,
        bool isRelative
    ) private pure returns (EthRequireIntentSegment memory) {
        //create new curve element
        EvaluationType evalType = EvaluationType.ABSOLUTE;
        if (isRelative) evalType = EvaluationType.RELATIVE;
        segment.requirement = EthCurve({
            timestamp: timestamp,
            flags: generateFlags(CurveBuilder.getCurveType(curveParams), evalType),
            params: curveParams
        });

        return segment;
    }

    function testNothing() public {}
}
