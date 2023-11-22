// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../../../../../src/interfaces/UserIntent.sol";
import "../../../../../src/standards/UserOperation.sol";

/**
 * @title UserOperationBuilder
 * Utility functions helpful for building a user operation.
 */
library UserOperationBuilder {
    /**
     * Add an intent segment to the user intent.
     * @param intent The user intent to modify.
     * @param segment The intent segment to add.
     * @return The updated user intent.
     */
    function addSegment(UserIntent memory intent, UserOperationSegment memory segment)
        public
        pure
        returns (UserIntent memory)
    {
        return encodeData(intent, segment);
    }

    /**
     * Encodes the user operation segments onto the user intent.
     * @param intent The user intent to modify.
     * @param segment The user operation segment to encode.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, UserOperationSegment memory segment)
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
     * Decodes the user operation segment at given index from the user intent.
     * @param intent The user intent to decode data from.
     * @param segmentIndex The index of segment.
     * @return The user operation data.
     */
    function decodeData(UserIntent memory intent, uint256 segmentIndex)
        public
        pure
        returns (UserOperationSegment memory)
    {
        bytes memory raw = new bytes(intent.intentData[segmentIndex].length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 j = 0; j < intent.intentData[segmentIndex].length; j++) {
            raw[j + 32] = intent.intentData[segmentIndex][j];
        }
        (UserOperationSegment memory decoded) = abi.decode(raw, (UserOperationSegment));
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
 * @title UserOperationSegmentBuilder
 * Utility functions helpful for building a user operation segment.
 */
library UserOperationSegmentBuilder {
    /**
     * Create a new intent segment with the specified parameters.
     * @param standard The standard ID for the intent segment.
     * @param callData The data for an intended call.
     * @param callGasLimit The gas limit for the intended call.
     * @return intent The created user intent segment.
     */
    function create(bytes32 standard, bytes memory callData, uint256 callGasLimit)
        public
        pure
        returns (UserOperationSegment memory)
    {
        return UserOperationSegment({standard: standard, callData: callData, callGasLimit: callGasLimit});
    }

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
