// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
//TODO: implement custom abi
//TODO: experiment with assembly ("memory-safe")

import {StatefulAbiEncoding, decodeSize, encodeSize} from "./StatefulAbiEncoding.sol";
import {Exec} from "../Exec.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {DataRegistry} from "./DataRegistry.sol";

/*
 * Solution template encoding
 * xxxxxxxx (timestamp) xx (num intents) [
 *     xx..xx (encoded sender)
 *     xx (num segments) [
 *         xx..xx (encoded standard) xx-xxxx (data length) xx..xx (data)
 *     ] ( segments)
 *     xx (signature length) xx..xx (signature)
 * ] (intents)
 * xx (execution order length) xx.. (order [each step is 5bits skipping the last bit if sequence goes beyond 256bits])
 */
bytes4 constant HANDLE_INTENTS_FN_SEL = 0x4bf114ff;
uint8 constant START_DATA_OFFSET = 0x20;
uint8 constant INTENTS_OFFSET = 0x60;
uint8 constant INTENT_DATA_OFFSET = 0x60;
uint256 constant PTR_SOLUTION_START = 32 + 4 + 32;
uint256 constant PTR_ORDER_OFFSET = 32 + 4 + 32 + 32 + 32;
uint256 constant PTR_INTENT_OFFSETS = 32 + 4 + 32 + 32 + 32 + 32 + 32;

/*
 * Contract that inflates a compressed templated version of a general intent solution
 */
contract GeneralIntentCompression is StatefulAbiEncoding {
    /**
     * EntryPoint
     */
    IEntryPoint public immutable entrypoint;

    /**
     * Constructor
     */
    constructor(IEntryPoint entry, DataRegistry registry) StatefulAbiEncoding(registry) {
        entrypoint = entry;
    }

    /*
     * Calls the handle intents function after expanding the given compressed solution
     */
    function handleIntents(bytes calldata data) external {
        bytes memory call = decompressHandleIntents(data);
        Exec.call(address(entrypoint), 0, call, gasleft());
    }

    /*
     * Expands the compressed solution into full handle intents call data
     */
    function decompressHandleIntents(bytes calldata data) internal view returns (bytes memory) {
        unchecked {
            bytes memory out = new bytes(decompressSize(data));
            uint256 outIndex = 32; //start at an extra slot so index can be directly used with mstore
            uint256 dataIndex = 0;

            //set function selector, data offset
            assembly {
                mstore(add(out, outIndex), HANDLE_INTENTS_FN_SEL)
                outIndex := add(outIndex, 4)
                mstore(add(out, outIndex), START_DATA_OFFSET)
                outIndex := add(outIndex, 32)
            }

            //set timestamp, intent offset, skip order offset
            assembly {
                let timestmp := calldataload(add(data.offset, dataIndex))
                dataIndex := add(dataIndex, 4)
                mstore(add(out, outIndex), shr(224, timestmp))
                outIndex := add(outIndex, 32)
                mstore(add(out, outIndex), INTENTS_OFFSET)
                outIndex := add(outIndex, 64)
            }

            //set num intents, skip intent offsets
            uint256 numIntents = uint256(uint8(data[dataIndex]));
            dataIndex += 1;
            assembly {
                mstore(add(out, outIndex), numIntents)
                outIndex := add(outIndex, add(32, mul(32, numIntents)))
            }

            //intents
            for (uint256 i = 0; i < numIntents; i++) {
                //set previously skipped intent offset
                assembly {
                    mstore(add(out, add(PTR_INTENT_OFFSETS, mul(i, 32))), sub(outIndex, PTR_INTENT_OFFSETS))
                }

                //decompress intent
                (dataIndex, outIndex) = decompressIntent(data, dataIndex, out, outIndex);
            }

            //set previously skipped order offset
            assembly {
                mstore(add(out, PTR_ORDER_OFFSET), sub(outIndex, PTR_SOLUTION_START))
            }

            //set order length
            uint256 numExecutionOrder = uint256(uint8(data[dataIndex]));
            dataIndex += 1;
            assembly {
                mstore(add(out, outIndex), numExecutionOrder)
                outIndex := add(outIndex, 32)
            }

            //set order
            for (uint256 i = 0; i < numExecutionOrder;) {
                bytes32 orders;
                assembly {
                    orders := calldataload(add(data.offset, dataIndex))
                    dataIndex := add(dataIndex, 32)
                }
                for (uint256 j = 0; j < 51 && i < numExecutionOrder; j++) {
                    assembly {
                        mstore(add(out, outIndex), shr(251, orders))
                        outIndex := add(outIndex, 32)
                    }
                    orders = orders << 5;
                    i++;
                }
            }

            return out;
        }
    }

    /*
     * Helper to expand the compressed solution into full abi encoding
     */
    function decompressIntent(bytes calldata data, uint256 dataIndex, bytes memory out, uint256 outIndex)
        private
        view
        returns (uint256, uint256)
    {
        unchecked {
            uint256 ptrIntentStart = outIndex;

            //set sender, intent data offset
            (bytes32 sender, uint256 senderEncSize) = decodeSingle(data[dataIndex:]);
            dataIndex += senderEncSize;
            assembly {
                mstore(add(out, outIndex), sender)
                outIndex := add(outIndex, 32)
                mstore(add(out, outIndex), INTENT_DATA_OFFSET)
                outIndex := add(outIndex, 32)
            }

            //skip signature offset
            uint256 ptrSignatureOffset = outIndex;
            outIndex += 32;

            //set num segments, skip segment offsets
            uint256 numSegments = uint256(uint8(data[dataIndex]));
            dataIndex += 1;
            assembly {
                mstore(add(out, outIndex), numSegments)
                outIndex := add(outIndex, 32)
            }
            uint256 ptrSegmentOffsets = outIndex;
            outIndex += numSegments * 32;

            //segments
            for (uint256 s = 0; s < numSegments; s++) {
                //set previously skipped segment offset
                assembly {
                    mstore(add(out, add(ptrSegmentOffsets, mul(s, 32))), sub(outIndex, ptrSegmentOffsets))
                }

                //decompress segment
                (dataIndex, outIndex) = decompressSegment(data, dataIndex, out, outIndex);
            }

            //set previously skipped signature offset
            assembly {
                mstore(add(out, ptrSignatureOffset), sub(outIndex, ptrIntentStart))
            }

            //set signature length
            uint256 sigLen = uint256(uint8(data[dataIndex]));
            dataIndex += 1;
            assembly {
                mstore(add(out, outIndex), sigLen)
                outIndex := add(outIndex, 32)
            }

            //set signature data
            assembly {
                calldatacopy(add(out, outIndex), add(data.offset, dataIndex), sigLen)
                dataIndex := add(dataIndex, sigLen)
            }

            //move the out index past the signature
            outIndex += roundUp32(sigLen);
            return (dataIndex, outIndex);
        }
    }

    /*
     * Helper to expand the compressed solution into full abi encoding
     */
    function decompressSegment(bytes calldata data, uint256 dataIndex, bytes memory out, uint256 outIndex)
        internal
        view
        returns (uint256, uint256)
    {
        unchecked {
            //get standard
            (bytes32 standard, uint256 standardEncSize) = decodeSingle(data[dataIndex:]);
            dataIndex += standardEncSize;

            //get encoded segment data length
            uint256 dataLenEncoded = uint256(uint8(data[dataIndex]));
            if (dataLenEncoded >= 128) {
                assembly {
                    dataLenEncoded := sub(shr(240, calldataload(add(data.offset, dataIndex))), 32768)
                }
                dataIndex += 2;
            } else {
                dataIndex += 1;
            }

            //set segment data
            uint256 decLen = decode(data[dataIndex:dataIndex + dataLenEncoded], out, (outIndex - 32) + 64);

            //set segment data length, standard
            assembly {
                mstore(add(out, outIndex), add(32, decLen))
                outIndex := add(outIndex, 32)
                mstore(add(out, outIndex), standard)
                outIndex := add(outIndex, 32)
            }

            //move the out index past the data
            dataIndex += dataLenEncoded;
            outIndex += roundUp32(decLen);
            return (dataIndex, outIndex);
        }
    }
}

/*
 * Gets the decompressed size of the compressed data
 */
function decompressSize(bytes calldata data) pure returns (uint256) {
    unchecked {
        uint256 decompressed = 0;
        uint256 dataIndex = 0;

        //function selector, data offset, timestamp, intents offset, order offset, num intents, order length
        decompressed += 4 + 32 + 32 + 32 + 32 + 32 + 32;

        //skip timestamp in encoding
        dataIndex += 4;

        //intent offsets, senders, data offsets, signature offsets, num segments, signature lengths
        uint256 numIntents = uint256(uint8(data[dataIndex]));
        dataIndex += 1;
        decompressed += numIntents * (32 + 32 + 32 + 32 + 32 + 32);

        //intents
        for (uint256 i = 0; i < numIntents; i++) {
            //skip sender in encoding
            dataIndex += encodeSize(data[dataIndex]);

            //segment offsets, byte lengths, standard ids
            uint256 numSegments = uint256(uint8(data[dataIndex]));
            dataIndex += 1;
            decompressed += numSegments * (32 + 32 + 32);

            //segments
            for (uint256 s = 0; s < numSegments; s++) {
                //skip standard in encoding
                dataIndex += encodeSize(data[dataIndex]);

                //segment data
                uint256 dataLenEncoded = uint256(uint8(data[dataIndex]));
                if (dataLenEncoded >= 128) {
                    assembly {
                        dataLenEncoded := sub(shr(240, calldataload(add(data.offset, dataIndex))), 32768)
                    }
                    dataIndex += 2;
                } else {
                    dataIndex += 1;
                }
                uint256 dataLenDecoded = decodeSize(data[dataIndex:dataIndex + dataLenEncoded]);
                dataIndex += dataLenEncoded;
                decompressed += roundUp32(dataLenDecoded);
            }

            //signature data
            uint256 sigLength = uint256(uint8(data[dataIndex]));
            dataIndex += 1 + sigLength;
            decompressed += roundUp32(sigLength);
        }

        //execution orders
        uint256 numExecutionOrder = uint256(uint8(data[dataIndex]));
        decompressed += numExecutionOrder * 32;

        return decompressed;
    }
}

/*
 * Rounds the given number up to the nearest 32
 */
function roundUp32(uint256 num) pure returns (uint256) {
    unchecked {
        uint256 round = (num >> 5) << 5;
        if (round < num) round += 32;
        return round;
    }
}
