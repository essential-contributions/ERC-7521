// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../../src/interfaces/UserIntent.sol";
import {
    EthRequireIntentCurve,
    generateEthRequireFlags,
    CurveType,
    EvaluationType
} from "../../../src/standards/ethRequire/EthRequireIntentCurve.sol";
import {
    EthRequireIntentStandard,
    EthRequireIntentSegment
} from "../../../src/standards/ethRequire/EthRequireIntentStandard.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title EthRequireIntentBuilder
 * Utility functions helpful for building an eth require intent.
 */
library EthRequireIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param standard The standard ID for the intent segment.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, bytes32 standard, EthRequireIntentSegment memory segment)
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
}

/**
 * @title EthRequireIntentSegmentBuilder
 * Utility functions helpful for building an eth require intent segment.
 */
library EthRequireIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @return intent The created user intent segment.
     */
    function create() public pure returns (EthRequireIntentSegment memory) {
        EthRequireIntentCurve memory requirement;

        return EthRequireIntentSegment({requirement: requirement});
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
     * Add an end state required asset of ETH to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent segment.
     */
    function requireETH(EthRequireIntentSegment memory segment, int256[] memory curve, bool relative)
        public
        pure
        returns (EthRequireIntentSegment memory)
    {
        return _addEthReqCurve(segment, curve, relative);
    }

    /**
     * Private helper function to add an eth release curve to a user intent segment.
     */
    function _addEthReqCurve(EthRequireIntentSegment memory segment, int256[] memory curveParams, bool isRelative)
        private
        pure
        returns (EthRequireIntentSegment memory)
    {
        //create new curve element
        EvaluationType evalType = EvaluationType.ABSOLUTE;
        if (isRelative) evalType = EvaluationType.RELATIVE;
        segment.requirement = EthRequireIntentCurve({
            flags: generateEthRequireFlags(getCurveType(curveParams), evalType),
            params: curveParams
        });

        return segment;
    }
}

/**
 * @title EthRequireIntentCurveBuilder
 * Utility functions helpful for building an eth require intent curve.
 */
library EthRequireIntentCurveBuilder {
    /**
     * @dev Helper function to generate curve parameters for a constant curve.
     * @param amount The constant value for the curve.
     * @return params The array containing the curve parameters.
     */
    function constantCurve(int256 amount) public pure returns (int256[] memory) {
        int256[] memory params = new int256[](1);
        params[0] = amount;
        return params;
    }

    /**
     * @dev Helper function to generate curve parameters for a linear curve.
     * @param m The slope of the linear curve.
     * @param b The y-intercept of the linear curve.
     * @param max The maximum x value for the curve.
     * @param flipY Boolean flag to indicate if the curve should be evaluated from right to left.
     * @return params The array containing the curve parameters.
     */
    function linearCurve(int256 m, int256 b, uint256 max, bool flipY) public pure returns (int256[] memory) {
        int256[] memory params = new int256[](3);
        int256 signedMax = int256(max);
        if (flipY) signedMax = -signedMax;
        params[0] = m;
        params[1] = b;
        params[2] = signedMax;
        return params;
    }

    /**
     * @dev Helper function to generate curve parameters for an exponential curve.
     * @param m The multiplier for the exponential curve.
     * @param b The base for the exponential curve.
     * @param e The exponent for the exponential curve.
     * @param max The maximum x value for the curve.
     * @param flipY Boolean flag to indicate if the curve should be evaluated from right to left.
     * @return params The array containing the curve parameters.
     */
    function exponentialCurve(int256 m, int256 b, int256 e, uint256 max, bool flipY)
        public
        pure
        returns (int256[] memory)
    {
        int256[] memory params = new int256[](4);
        int256 signedMax = int256(max);
        if (flipY) signedMax = -signedMax;
        params[0] = m;
        params[1] = b;
        params[2] = e;
        params[3] = signedMax;
        return params;
    }
}
