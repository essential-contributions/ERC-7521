// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {UserIntent} from "../../../../../src/interfaces/UserIntent.sol";
import {Erc20Curve, CurveType, EvaluationType} from "../../../../../src/utils/curves/Erc20Curve.sol";
import {CurveBuilder} from "../CurveBuilder.sol";
import {generateFlags} from "../../../../../src/utils/Helpers.sol";
import {
    Erc20ReleaseIntentStandard,
    Erc20ReleaseIntentSegment
} from "../../../../../src/standards/Erc20ReleaseIntentStandard.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title Erc20ReleaseIntentBuilder
 * Utility functions helpful for building an erc20 release intent.
 */
library Erc20ReleaseIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, Erc20ReleaseIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        return encodeData(intent, segment);
    }

    /**
     * Encodes the erc20 release intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The erc20 release intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, Erc20ReleaseIntentSegment memory segment)
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
     * Decodes the erc20 release intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The erc20 release intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (Erc20ReleaseIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        Erc20ReleaseIntentSegment memory decoded = abi.decode(raw, (Erc20ReleaseIntentSegment));
        return decoded;
    }

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}

/**
 * @title Erc20ReleaseIntentSegmentBuilder
 * Utility functions helpful for building an erc20 release intent segment.
 */
library Erc20ReleaseIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @param standard The standard ID for the intent segment.
     * @return intent The created user intent segment.
     */
    function create(bytes32 standard) public pure returns (Erc20ReleaseIntentSegment memory) {
        Erc20Curve memory erc20Release;

        return Erc20ReleaseIntentSegment({standard: standard, release: erc20Release});
    }

    /**
     * Add an erc20 release for ERC20 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC20 token contract.
     * @param curve The curve parameters for the erc20 release.
     * @return The updated user intent segment.
     */
    function releaseErc20(
        Erc20ReleaseIntentSegment memory segment,
        address addr,
        uint48 timestamp,
        int256[] memory curve
    ) public pure returns (Erc20ReleaseIntentSegment memory) {
        return _addErc20RelCurve(segment, addr, timestamp, curve);
    }

    /**
     * Private helper function to add an erc20 release curve to a user intent segment.
     */
    function _addErc20RelCurve(
        Erc20ReleaseIntentSegment memory segment,
        address erc20Contract,
        uint48 timestamp,
        int256[] memory curveParams
    ) private pure returns (Erc20ReleaseIntentSegment memory) {
        segment.release = Erc20Curve({
            erc20Contract: erc20Contract,
            timestamp: timestamp,
            flags: generateFlags(CurveBuilder.getCurveType(curveParams), EvaluationType.ABSOLUTE),
            params: curveParams
        });

        return segment;
    }

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
