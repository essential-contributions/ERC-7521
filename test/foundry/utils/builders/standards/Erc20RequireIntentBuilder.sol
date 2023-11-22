// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {UserIntent} from "../../../../../src/interfaces/UserIntent.sol";
import {Erc20Curve, CurveType, EvaluationType} from "../../../../../src/utils/curves/Erc20Curve.sol";
import {CurveBuilder} from "../CurveBuilder.sol";
import {
    Erc20RequireIntentStandard,
    Erc20RequireIntentSegment
} from "../../../../../src/standards/Erc20RequireIntentStandard.sol";
import {generateFlags} from "../../../../../src/utils/Helpers.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @title Erc20RequireIntentBuilder
 * Utility functions helpful for building an erc20 require intent.
 */
library Erc20RequireIntentBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, Erc20RequireIntentSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        return encodeData(intent, segment);
    }

    /**
     * Encodes the erc20 require intent segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The erc20 require intent standard segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, Erc20RequireIntentSegment memory segment)
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
     * Decodes the erc20 require intent segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The erc20 require intent data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (Erc20RequireIntentSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        Erc20RequireIntentSegment memory decoded = abi.decode(raw, (Erc20RequireIntentSegment));
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
 * @title Erc20RequireIntentSegmentBuilder
 * Utility functions helpful for building an erc20 require intent segment.
 */
library Erc20RequireIntentSegmentBuilder {
    /**
     * Create a new intent segment.
     * @param standard The standard ID for the intent segment.
     * @return intent The created user intent segment.
     */
    function create(bytes32 standard) public pure returns (Erc20RequireIntentSegment memory) {
        Erc20Curve memory erc20Requirement;

        return Erc20RequireIntentSegment({standard: standard, requirement: erc20Requirement});
    }

    /**
     * Add an end state required erc20 of ERC20 tokens to the user intent segment.
     * @param segment The user intent segment to modify.
     * @param addr The address of the ERC20 token contract.
     * @param curve The curve parameters for the erc20 requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent segment.
     */
    function requireErc20(
        Erc20RequireIntentSegment memory segment,
        address addr,
        uint48 timestamp,
        int256[] memory curve,
        bool relative
    ) public pure returns (Erc20RequireIntentSegment memory) {
        return _addErc20ReqCurve(segment, addr, timestamp, curve, relative);
    }

    /**
     * Private helper function to add an erc20 release curve to a user intent segment.
     */
    function _addErc20ReqCurve(
        Erc20RequireIntentSegment memory segment,
        address erc20Contract,
        uint48 timestamp,
        int256[] memory curveParams,
        bool isRelative
    ) private pure returns (Erc20RequireIntentSegment memory) {
        //create new curve element
        EvaluationType evalType = EvaluationType.ABSOLUTE;
        if (isRelative) evalType = EvaluationType.RELATIVE;
        segment.requirement = Erc20Curve({
            erc20Contract: erc20Contract,
            timestamp: timestamp,
            flags: generateFlags(CurveBuilder.getCurveType(curveParams), evalType),
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
