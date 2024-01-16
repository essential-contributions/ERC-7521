// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */
/* solhint-disable func-name-mixedcase */

//TODO: experiment with assembly ("memory-safe")

import {StatefulAbiEncoding, decodeSize, encodeSize} from "./StatefulAbiEncoding.sol";
import {Exec} from "../../utils/Exec.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {DataRegistry} from "./DataRegistry.sol";

/* Handle intents encoding
 * xx (num solutions) [
 *    xx..xx (encoded solution)
 * ] (solutions)
 *   --if first bit in "num solutions" is 1--
 * xx..xx (encoded aggregator)
 * xx..xx (intents to aggregate)
 * xx (signature length) xx..xx (signature)
 */
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

// Common decoding constants
bytes4 constant HANDLE_INTENTS_FN_SEL = 0x4bf114ff;
uint8 constant START_DATA_OFFSET = 0x20;
uint256 constant HANDLE_AGGREGATED_FLAG = 0x80;

// Multi decoding constants
bytes4 constant HANDLE_INTENTS_MULTI_FN_SEL = 0x7cfc1a5d;
uint256 constant MUL_PTR_SOL_OFFSETS = 32 + 4 + 32 + 32; //includes 32 + 4 for array length and fn selector

// Aggregated decoding constants
bytes4 constant HANDLE_INTENTS_AGGR_FN_SEL = 0xf551237e;
uint8 constant AGG_SOLUTIONS_OFFSET = 0x80;
uint256 constant AGG_DATA_START = 32 + 4; //includes 32 + 4 for array length and fn selector
uint256 constant AGG_PTR_AGGREGATOR = 32 + 4 + 32; //includes 32 + 4 for array length and fn selector
uint256 constant AGG_PTR_INT_TO_AGG = 32 + 4 + 32 + 32; //includes 32 + 4 for array length and fn selector
uint256 constant AGG_PTR_SIGN_OFFSET = 32 + 4 + 32 + 32 + 32; //includes 32 + 4 for array length and fn selector
uint256 constant AGG_PTR_SOL_OFFSETS = 32 + 4 + 32 + 32 + 32 + 32 + 32; //includes 32 + 4 for array length and fn selector

// Solution decoding constants
uint8 constant SOL_INTENTS_OFFSET = 0x60;
uint8 constant SOL_INTENT_DATA_OFFSET = 0x60;
uint256 constant SOL_PTR_ORDER_OFFSET = 32 + 32; //relative to the start of the solution data
uint256 constant SOL_PTR_INTENT_OFFSETS = 32 + 32 + 32 + 32; //relative to the start of the solution data

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
    fallback() external {
        bytes calldata data;
        assembly {
            data.offset := 0
            data.length := calldatasize()
        }
        bytes memory call = decompressToCalldata(data);
        bool success = Exec.call(address(entrypoint), 0, call, gasleft());
        if (!success) Exec.forwardRevert(Exec.REVERT_REASON_MAX_LEN);
    }

    /*
     * Expands the compressed solution into full handle intents call data
     */
    function decompressToCalldata(bytes calldata data) internal view returns (bytes memory) {
        unchecked {
            bytes memory out = new bytes(decompressSize(data));
            uint256 numSolutions = uint256(uint8(data[0]));
            uint256 outIndex = 32; //start at an extra slot so index can be directly used with mstore
            uint256 dataIndex = 1;
            if (numSolutions == 0) {
                //handleIntents()

                //set function selector, data offset
                assembly {
                    mstore(add(out, outIndex), HANDLE_INTENTS_FN_SEL)
                    outIndex := add(outIndex, 4)
                    mstore(add(out, outIndex), START_DATA_OFFSET)
                    outIndex := add(outIndex, 32)
                }

                //set solution
                (dataIndex, outIndex) = decompressSolution(data, dataIndex, out, outIndex);
            } else if (numSolutions < HANDLE_AGGREGATED_FLAG) {
                //handleIntentsMulti()

                //set function selector, data offset, num solutions
                assembly {
                    mstore(add(out, outIndex), HANDLE_INTENTS_MULTI_FN_SEL)
                    outIndex := add(outIndex, 4)
                    mstore(add(out, outIndex), START_DATA_OFFSET)
                    outIndex := add(outIndex, 32)
                }

                //set num solutions, skip solution offsets
                assembly {
                    mstore(add(out, outIndex), numSolutions)
                    outIndex := add(outIndex, add(32, mul(32, numSolutions)))
                }

                //solutions
                for (uint256 i = 0; i < numSolutions; i++) {
                    //set previously skipped solution offset
                    assembly {
                        mstore(add(out, add(MUL_PTR_SOL_OFFSETS, mul(i, 32))), sub(outIndex, MUL_PTR_SOL_OFFSETS))
                    }

                    //decompress solution
                    (dataIndex, outIndex) = decompressSolution(data, dataIndex, out, outIndex);
                }
            } else if (numSolutions > HANDLE_AGGREGATED_FLAG) {
                //handleIntentsAggregated()
                numSolutions = numSolutions - HANDLE_AGGREGATED_FLAG;

                //set function selector, solutions offset
                assembly {
                    mstore(add(out, outIndex), HANDLE_INTENTS_AGGR_FN_SEL)
                    outIndex := add(outIndex, 4)
                    mstore(add(out, outIndex), AGG_SOLUTIONS_OFFSET)
                    outIndex := add(outIndex, 32)
                }

                //skip aggregator, intents to aggregate, signature offset
                outIndex += 32 + 32 + 32;

                //set num solutions, skip solution offsets
                assembly {
                    mstore(add(out, outIndex), numSolutions)
                    outIndex := add(outIndex, add(32, mul(32, numSolutions)))
                }

                //solutions
                uint256 totalIntents = 0;
                for (uint256 i = 0; i < numSolutions; i++) {
                    //set previously skipped solution offset
                    assembly {
                        mstore(add(out, add(AGG_PTR_SOL_OFFSETS, mul(i, 32))), sub(outIndex, AGG_PTR_SOL_OFFSETS))
                    }

                    //keep track of total number of intents
                    totalIntents += countIntents(data, dataIndex);

                    //decompress solution
                    (dataIndex, outIndex) = decompressSolution(data, dataIndex, out, outIndex);
                }

                //set previously skipped aggregator
                {
                    (bytes32 aggregator, uint256 aggregatorEncSize) = decodeSingle(data[dataIndex:]);
                    dataIndex += aggregatorEncSize;
                    assembly {
                        mstore(add(out, AGG_PTR_AGGREGATOR), aggregator)
                    }
                }

                //set previously skipped intents to aggregate
                {
                    uint256 intsToAggregateEncSize = (totalIntents + 7) / 8;
                    assembly {
                        let intsToAggregate :=
                            shr(sub(256, shl(3, intsToAggregateEncSize)), calldataload(add(data.offset, dataIndex)))
                        mstore(add(out, AGG_PTR_INT_TO_AGG), intsToAggregate)
                    }
                    dataIndex += intsToAggregateEncSize;
                }

                //set previously skipped signature offset
                assembly {
                    mstore(add(out, AGG_PTR_SIGN_OFFSET), sub(outIndex, AGG_DATA_START))
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
                outIndex += roundUp32(sigLen);
            } else {
                revert("Invalid encoding prefix");
            }
            return out;
        }
    }

    /*
     * Expands the compressed solution into full handle intents call data
     */
    function decompressSolution(bytes calldata data, uint256 dataIndex, bytes memory out, uint256 outIndex)
        private
        view
        returns (uint256, uint256)
    {
        uint256 solutionStartIndex = outIndex;
        unchecked {
            //set timestamp, intent offset, skip order offset
            assembly {
                let timestmp := calldataload(add(data.offset, dataIndex))
                dataIndex := add(dataIndex, 4)
                mstore(add(out, outIndex), shr(224, timestmp))
                outIndex := add(outIndex, 32)
                mstore(add(out, outIndex), SOL_INTENTS_OFFSET)
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
                    let start := add(solutionStartIndex, SOL_PTR_INTENT_OFFSETS)
                    mstore(add(out, add(start, mul(i, 32))), sub(outIndex, start))
                }

                //decompress intent
                (dataIndex, outIndex) = decompressIntent(data, dataIndex, out, outIndex);
            }

            //set previously skipped order offset
            assembly {
                mstore(add(out, add(solutionStartIndex, SOL_PTR_ORDER_OFFSET)), sub(outIndex, solutionStartIndex))
            }

            //set order length
            uint256 numExecutionOrder = uint256(uint8(data[dataIndex]));
            dataIndex += 1;
            assembly {
                mstore(add(out, outIndex), numExecutionOrder)
                outIndex := add(outIndex, 32)
            }

            //set order
            uint256 dIdx = dataIndex;
            for (uint256 i = 0; i < numExecutionOrder;) {
                bytes32 orders;
                assembly {
                    orders := calldataload(add(data.offset, dIdx))
                    dIdx := add(dIdx, 32)
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
            dataIndex += (numExecutionOrder * 5 + (numExecutionOrder / 51) + 7) / 8;

            return (dataIndex, outIndex);
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
                mstore(add(out, outIndex), SOL_INTENT_DATA_OFFSET)
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

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test_test() public {}
}

/*
 * Gets the decompressed size of the compressed data
 */
function decompressSize(bytes calldata data) pure returns (uint256) {
    unchecked {
        uint256 numSolutions = uint256(uint8(data[0]));
        uint256 decompressed = 0;
        uint256 dataIndex = 1;
        uint256 size = 0;
        if (numSolutions == 0) {
            //handleIntents()

            //function selector, data offset
            decompressed += 4 + 32;

            //solution size
            (size, dataIndex) = decompressSolutionSize(data, dataIndex);
            decompressed += size;
        } else if (numSolutions < HANDLE_AGGREGATED_FLAG) {
            //handleIntentsMulti()

            //set function selector, data offset, num solutions, solution offsets
            decompressed += 4 + 32 + 32 + numSolutions * 32;

            //solution sizes
            for (uint256 i = 0; i < numSolutions; i++) {
                (size, dataIndex) = decompressSolutionSize(data, dataIndex);
                decompressed += size;
            }
        } else if (numSolutions > HANDLE_AGGREGATED_FLAG) {
            //handleIntentsAggregated()
            numSolutions = numSolutions - HANDLE_AGGREGATED_FLAG;

            //set function selector, solutions offset, aggregator, intents to aggregate,
            //signature offset, num solutions, solution offsets
            decompressed += 4 + 32 + 32 + 32 + 32 + 32 + numSolutions * 32;

            //solution sizes
            for (uint256 i = 0; i < numSolutions; i++) {
                (size, dataIndex) = decompressSolutionSize(data, dataIndex);
                decompressed += size;
            }

            //signature data
            uint256 sigLength = uint256(uint8(data[dataIndex]));
            dataIndex += 1 + sigLength;
            decompressed += 32 + roundUp32(sigLength);
        } else {
            revert("Invalid encoding prefix");
        }
        return decompressed;
    }
}

/*
 * Gets the decompressed size of an encoded solution
 */
function decompressSolutionSize(bytes calldata data, uint256 dataIndex) pure returns (uint256, uint256) {
    unchecked {
        uint256 decompressed = 0;

        //timestamp, intents offset, order offset, num intents, order length
        decompressed += 32 + 32 + 32 + 32 + 32;

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
        dataIndex += 1 + (numExecutionOrder * 5 + (numExecutionOrder / 51) + 7) / 8;
        decompressed += numExecutionOrder * 32;

        return (decompressed, dataIndex);
    }
}

/*
 * Gets the number of intents in an encoded solution
 */
function countIntents(bytes calldata data, uint256 dataIndex) pure returns (uint256) {
    unchecked {
        //skip timestamp in encoding (4 bytes)
        return uint256(uint8(data[dataIndex + 4]));
    }
}

/*
 * Rounds the given number up to the nearest 32
 */
function roundUp32(uint256 num) pure returns (uint256) {
    unchecked {
        return ((num + 31) >> 5) << 5;
    }
}
