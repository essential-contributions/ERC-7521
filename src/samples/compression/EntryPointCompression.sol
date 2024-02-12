// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDataRegistry} from "./interfaces/IDataRegistry.sol";
import {
    CalldataCompression,
    DICTIONARY_L1_SIZE,
    DICTIONARY_L1_LENGTHS_OFFSET,
    DICTIONARY_L1_DATA_OFFSET
} from "./core/CalldataCompression.sol";

/**
 * Contract that inflates a compressed templated version of a general intent solution
 */
contract EntryPointCompression is CalldataCompression {
    /**
     * Constructor
     */
    constructor(address target, IDataRegistry l2Registry, IDataRegistry l3Registry, bytes4 l3RegisterFnSel)
        CalldataCompression(target, l2Registry, l3Registry, l3RegisterFnSel)
    {}

    /**
     * Function to load that static L1 dictionary for the target
     * @dev this is the one function inheriting contracts must implement to help tailor
     * stateful dictionaries to the intended target
     */
    function staticL1Dictionary() internal pure override returns (bytes memory) {
        bytes memory dictionary = new bytes(DICTIONARY_L1_SIZE);
        uint256 startOffset = DICTIONARY_L1_DATA_OFFSET;
        uint256 lengthsOffset = DICTIONARY_L1_LENGTHS_OFFSET;
        assembly ("memory-safe") {
            let ptr := add(dictionary, startOffset)
            let len := add(dictionary, lengthsOffset)
            mstore(add(ptr, 0x0000), 0x0000000000000000000000000000000000000000000000000000000000000001)
            mstore8(add(len, 0), 32)
            mstore(add(ptr, 0x0020), 0x0000000000000000000000000000000000000000000000000000000000000002)
            mstore8(add(len, 1), 32)
            mstore(add(ptr, 0x0040), 0x0000000000000000000000000000000000000000000000000000000000000003)
            mstore8(add(len, 2), 32)
            mstore(add(ptr, 0x0060), 0x0000000000000000000000000000000000000000000000000000000000000004)
            mstore8(add(len, 3), 32)
            mstore(add(ptr, 0x0080), 0x0000000000000000000000000000000000000000000000000000000000000005)
            mstore8(add(len, 4), 32)
            mstore(add(ptr, 0x00a0), 0x0000000000000000000000000000000000000000000000000000000000000006)
            mstore8(add(len, 5), 32)
            mstore(add(ptr, 0x00c0), 0x0000000000000000000000000000000000000000000000000000000000000007)
            mstore8(add(len, 6), 32)
            mstore(add(ptr, 0x00e0), 0x0000000000000000000000000000000000000000000000000000000000000008)
            mstore8(add(len, 7), 32)
            mstore(add(ptr, 0x0100), 0x0000000000000000000000000000000000000000000000000000000000000009)
            mstore8(add(len, 8), 32)
            mstore(add(ptr, 0x0120), 0x000000000000000000000000000000000000000000000000000000000000000a)
            mstore8(add(len, 9), 32)
            mstore(add(ptr, 0x0140), 0x000000000000000000000000000000000000000000000000000000000000000b)
            mstore8(add(len, 10), 32)
            mstore(add(ptr, 0x0160), 0x000000000000000000000000000000000000000000000000000000000000000c)
            mstore8(add(len, 11), 32)
            mstore(add(ptr, 0x0180), 0x000000000000000000000000000000000000000000000000000000000000000d)
            mstore8(add(len, 12), 32)
            mstore(add(ptr, 0x01a0), 0x000000000000000000000000000000000000000000000000000000000000000e)
            mstore8(add(len, 13), 32)
            mstore(add(ptr, 0x01c0), 0x000000000000000000000000000000000000000000000000000000000000000f)
            mstore8(add(len, 14), 32)
            mstore(add(ptr, 0x01e0), 0x4bf114ff00000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 15), 4)
            mstore(add(ptr, 0x0200), 0x7cfc1a5d00000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 16), 4)
            mstore(add(ptr, 0x0220), 0xf551237e00000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 17), 4)
            mstore(add(ptr, 0x0240), 0x0000000000000000000000000000000000000000000000000000000000000020)
            mstore8(add(len, 18), 32)
            mstore(add(ptr, 0x0260), 0x0000000000000000000000000000000000000000000000000000000000000060)
            mstore8(add(len, 19), 32)
            mstore(add(ptr, 0x0280), 0x0000000000000000000000000000000000000000000000000000000000000080)
            mstore8(add(len, 20), 32)
            mstore(add(ptr, 0x02a0), 0x0000000000000000000000000000000000000000000000000000000000000041)
            mstore8(add(len, 21), 32)
            mstore(add(ptr, 0x02c0), 0x0000000000000000000000003aa5ebb10dc797cac828524e59a333d0a371443c)
            mstore8(add(len, 22), 32)
            /*
            mstore(add(ptr, 0x02e0), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 23), 32)
            mstore(add(ptr, 0x0300), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 24), 32)
            mstore(add(ptr, 0x0320), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 25), 32)
            mstore(add(ptr, 0x0340), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 26), 32)
            mstore(add(ptr, 0x0360), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 27), 32)
            mstore(add(ptr, 0x0380), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 28), 32)
            mstore(add(ptr, 0x03a0), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 29), 32)
            mstore(add(ptr, 0x03c0), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 30), 32)
            mstore(add(ptr, 0x03e0), 0x0000000000000000000000000000000000000000000000000000000000000000)
            mstore8(add(len, 31), 32)
            */
        }
        return dictionary;
    }
}
