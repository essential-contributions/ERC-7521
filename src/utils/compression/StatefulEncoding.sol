// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
//TODO: experiment with assembly ("memory-safe")

/*
 * Encoding prefixes
 * 00x - 1 byte stateful common bytes [0-63] (extremely common addresses, function selectors, etc)
 * 010 - 2 byte stateful common bytes [0-16,383] (function selectors, lengths of Zeros, etc)
 * 011 - 4 byte stateful common bytes [0-536,870,911] (addresses, hashes, etc)
 * 100 - zeros [1-32]
 * 101 - zero padded bytes (to 32) [1-32 num bytes]
 * 110 - regular bytes [1-32 num bytes]
 * 111 - 6-10 byte compressed 256bit number
 */
bytes1 constant PF_TYPE1_MASK = 0xc0;
bytes1 constant PF_TYPE2_MASK = 0xe0;

/*
 * Two byte registry has a special bin for different data lengths
 */
uint256 constant MAX_ONE_BYTE = 64;
uint256 constant MAX_TWO_BYTE = 6144;
uint256 constant MAX_FOUR_BYTE = 536870912;
uint256 constant MAX_FN_SEL_BIN = 2048;
uint256 constant FN_SEL_BIN_START = 6144;

/*
 * Contract that stores data to help with compression of common abi patterns
 */
contract StatefulEncoding {
    /**
     * Registry mappings
     */
    mapping(uint256 => bytes32) public oneByteRegistry;
    mapping(uint256 => bytes32) public twoByteRegistry;
    mapping(uint256 => bytes32) public fourByteRegistry;
    mapping(uint256 => bytes4) public fnSelRegistry;
    uint256 public oneByteRegistryLength;
    uint256 public twoByteRegistryLength;
    uint256 public fourByteRegistryLength;
    uint256 public fnSelRegistryLength;

    /**
     * Events
     */
    event OneByteRegistryAdd(uint256 indexed index, bytes32 data);
    event TwoByteRegistryAdd(uint256 indexed index, bytes32 data);
    event FourByteRegistryAdd(uint256 indexed index, bytes32 data);
    event FnSelRegistryAdd(uint256 indexed index, bytes4 data);

    /**
     * Adds bytes to the single byte encoding registry
     */
    function addOneByteItem(bytes32 data) external {
        uint256 index = oneByteRegistryLength;
        if (index < MAX_ONE_BYTE) {
            oneByteRegistry[index] = data;
            oneByteRegistryLength = index + 1;
            emit OneByteRegistryAdd(index, data);
        }
    }

    /**
     * Adds bytes to the two byte encoding registry
     */
    function addTwoByteItem(bytes32 data) external {
        uint256 index = twoByteRegistryLength;
        if (index < MAX_TWO_BYTE) {
            twoByteRegistry[index] = data;
            twoByteRegistryLength = index + 1;
            emit TwoByteRegistryAdd(index, data);
        }
    }

    /**
     * Adds bytes to the four byte encoding registry
     */
    function addFourByteItem(bytes32 data) external {
        uint256 index = fourByteRegistryLength;
        if (index < MAX_FOUR_BYTE) {
            fourByteRegistry[index] = data;
            fourByteRegistryLength = index + 1;
            emit FourByteRegistryAdd(index, data);
        }
    }

    /**
     * Adds bytes to the function selector encoding registry
     */
    function addFunctionSelector(bytes4 data) external {
        uint256 index = fnSelRegistryLength;
        if (index < MAX_FN_SEL_BIN) {
            fnSelRegistry[index] = data;
            fnSelRegistryLength = index + 1;
            emit FnSelRegistryAdd(index, data);
        }
    }

    /*
     * Gets the decoded bytes of the encoded data
     */
    function decode(bytes calldata data, bytes memory out, uint256 startIndex) internal view returns (uint256) {
        unchecked {
            uint256 outIndex = startIndex + 32; //add an extra slot so index can be directly used with mstore
            uint256 dataIndex = 0;
            while (dataIndex < data.length) {
                bytes1 prefix = data[dataIndex];
                if ((prefix & 0x80) == 0x00) {
                    if ((prefix & 0x40) == 0x00) {
                        //00x - 1 byte stateful common bytes [0-63]
                        bytes32 reg = oneByteRegistry[uint256(uint8(prefix & ~PF_TYPE1_MASK))];
                        assembly {
                            mstore(add(out, outIndex), reg)
                        }
                        outIndex += 32;
                        dataIndex += 1;
                    } else {
                        if ((prefix & 0x20) == 0x00) {
                            //010 - 2 byte stateful common bytes [0-8192]
                            bytes2 prefix2;
                            assembly {
                                prefix2 := calldataload(add(data.offset, dataIndex))
                            }
                            if (uint8(prefix & ~PF_TYPE2_MASK) < (FN_SEL_BIN_START >> 8)) {
                                bytes32 reg = twoByteRegistry[uint256(uint16(prefix2 & ~bytes2(PF_TYPE2_MASK)))];
                                assembly {
                                    mstore(add(out, outIndex), reg)
                                }
                                outIndex += 32;
                            } else {
                                bytes4 reg =
                                    fnSelRegistry[uint256(uint16(prefix2 & ~bytes2(PF_TYPE2_MASK))) - FN_SEL_BIN_START];
                                assembly {
                                    let tmp := shr(32, shl(32, mload(add(out, outIndex))))
                                    mstore(add(out, outIndex), or(reg, tmp))
                                }
                                outIndex += 4;
                            }
                            dataIndex += 2;
                        } else {
                            //011 - 4 byte stateful common bytes [0-536870911]
                            bytes4 prefix4;
                            assembly {
                                prefix4 := calldataload(add(data.offset, dataIndex))
                            }
                            bytes32 reg = fourByteRegistry[uint256(uint32(prefix4 & ~bytes4(PF_TYPE2_MASK)))];
                            assembly {
                                mstore(add(out, outIndex), reg)
                            }
                            outIndex += 32;
                            dataIndex += 4;
                        }
                    }
                } else {
                    if ((prefix & 0x40) == 0x00) {
                        if ((prefix & 0x20) == 0x00) {
                            //100 - zeros [1-32]
                            outIndex += uint8(prefix & ~PF_TYPE2_MASK) + 1;
                            dataIndex += 1;
                        } else {
                            //101 - zero padded bytes (to 32) [1-32 num bytes]
                            uint256 numZeros = uint8(prefix & ~PF_TYPE2_MASK) + 1;
                            uint256 numBytes = 32 - numZeros;
                            dataIndex += 1;
                            assembly {
                                let padded := shr(shl(3, numZeros), calldataload(add(data.offset, dataIndex)))
                                mstore(add(out, outIndex), padded)
                            }
                            outIndex += 32;
                            dataIndex += numBytes;
                        }
                    } else {
                        if ((prefix & 0x20) == 0x00) {
                            //110 - regular bytes [1-32 num bytes]
                            uint256 numBytes = uint8(prefix & ~PF_TYPE2_MASK) + 1;
                            dataIndex += 1;
                            assembly {
                                calldatacopy(add(out, outIndex), add(data.offset, dataIndex), numBytes)
                            }
                            outIndex += numBytes;
                            dataIndex += numBytes;
                        } else {
                            //111 - compressed decimal number
                            uint8 precision = uint8(prefix & 0x07);
                            if (precision < 4) precision = precision + 1;
                            else if (precision < 6) precision = ((precision - 4) * 2) + 6;
                            else precision = ((precision - 6) * 4) + 12;
                            dataIndex += 1;

                            uint256 num;
                            assembly {
                                num := shr(sub(256, shl(3, precision)), calldataload(add(data.offset, dataIndex)))
                            }
                            dataIndex += precision;

                            uint8 mult;
                            assembly {
                                mult := shr(248, calldataload(add(data.offset, dataIndex)))
                            }
                            num = num * tenToThePowerOf(mult);
                            dataIndex += 1;

                            uint8 size = uint8(prefix >> 3) & 0x03;
                            if (size == 3) {
                                assembly {
                                    mstore(add(out, outIndex), num)
                                }
                                outIndex += 32;
                            } else if (size == 2) {
                                assembly {
                                    let tmp := shr(128, shl(128, mload(add(out, outIndex))))
                                    mstore(add(out, outIndex), or(shl(128, num), tmp))
                                }
                                outIndex += 16;
                            } else if (size == 2) {
                                assembly {
                                    let tmp := shr(64, shl(64, mload(add(out, outIndex))))
                                    mstore(add(out, outIndex), or(shl(192, num), tmp))
                                }
                                outIndex += 8;
                            } else {
                                assembly {
                                    let tmp := shr(32, shl(32, mload(add(out, outIndex))))
                                    mstore(add(out, outIndex), or(shl(224, num), tmp))
                                }
                                outIndex += 4;
                            }
                        }
                    }
                }
            }
            return (outIndex - 32) - startIndex;
        }
    }

    /*
     * Gets the single decoded entry from the encoded data
     */
    function decodeSingle(bytes calldata data) internal view returns (bytes32, uint256) {
        unchecked {
            bytes1 prefix = data[0];
            if ((prefix & 0x80) == 0x00) {
                if ((prefix & 0x40) == 0x00) {
                    //00x - 1 byte stateful common bytes [0-63]
                    return (oneByteRegistry[uint256(uint8(prefix & ~PF_TYPE1_MASK))], 1);
                } else {
                    if ((prefix & 0x20) == 0x00) {
                        //010 - 2 byte stateful common bytes [0-8192]
                        bytes2 prefix2;
                        assembly {
                            prefix2 := calldataload(data.offset)
                        }
                        if (uint8(prefix & ~PF_TYPE2_MASK) < (FN_SEL_BIN_START >> 8)) {
                            return (twoByteRegistry[uint256(uint16(prefix2 & ~bytes2(PF_TYPE2_MASK)))], 2);
                        } else {
                            return (
                                bytes32(
                                    fnSelRegistry[uint256(uint16(prefix2 & ~bytes2(PF_TYPE2_MASK))) - FN_SEL_BIN_START]
                                    ),
                                2
                            );
                        }
                    } else {
                        //011 - 4 byte stateful common bytes [0-536870911]
                        bytes4 prefix4;
                        assembly {
                            prefix4 := calldataload(data.offset)
                        }
                        return (fourByteRegistry[uint256(uint32(prefix4 & ~bytes4(PF_TYPE2_MASK)))], 4);
                    }
                }
            } else {
                if ((prefix & 0x40) == 0x00) {
                    if ((prefix & 0x20) == 0x00) {
                        //100 - zeros [1-32]
                        return (bytes32(0), 1);
                    } else {
                        //101 - zero padded bytes (to 32) [1-32 num bytes]
                        uint256 numZeros = uint8(prefix & ~PF_TYPE2_MASK) + 1;
                        bytes32 padded;
                        assembly {
                            padded := shr(shl(3, numZeros), calldataload(add(data.offset, 1)))
                        }
                        return (padded, 33 - numZeros);
                    }
                } else {
                    if ((prefix & 0x20) == 0x00) {
                        //110 - regular bytes [1-32 num bytes]
                        uint256 numBytes = uint8(prefix & ~PF_TYPE2_MASK) + 1;
                        bytes32 byts;
                        assembly {
                            byts := shr(sub(256, shl(3, numBytes)), calldataload(add(data.offset, 1)))
                        }
                        return (byts, numBytes + 1);
                    } else {
                        //111 - compressed decimal number
                        uint8 precision = uint8(prefix & 0x07);
                        if (precision < 4) precision = precision + 1;
                        else if (precision < 6) precision = ((precision - 4) * 2) + 6;
                        else precision = ((precision - 6) * 4) + 12;

                        uint256 num;
                        uint8 mult;
                        assembly {
                            num := shr(sub(256, shl(3, precision)), calldataload(add(data.offset, 1)))
                            mult := shr(248, calldataload(add(data.offset, add(precision, 1))))
                        }
                        return (bytes32(num * tenToThePowerOf(mult)), precision + 2);
                    }
                }
            }
        }
    }
}

/*
 * Gets the decoded size of the encoded data
 */
function decodeSize(bytes calldata data) pure returns (uint256) {
    unchecked {
        uint256 decoded = 0;
        uint256 index = 0;
        while (index < data.length) {
            bytes1 prefix = data[index];
            if ((prefix & 0x80) == 0x00) {
                if ((prefix & 0x40) == 0x00) {
                    //00x - 1 byte stateful common bytes [0-63]
                    decoded += 32;
                    index += 1;
                } else {
                    if ((prefix & 0x20) == 0x00) {
                        //010 - 2 byte stateful common bytes [0-8192]
                        if (uint8(prefix & ~PF_TYPE2_MASK) < (FN_SEL_BIN_START >> 8)) decoded += 32;
                        else decoded += 4;
                        index += 2;
                    } else {
                        //011 - 4 byte stateful common bytes [0-536870911]
                        decoded += 32;
                        index += 4;
                    }
                }
            } else {
                if ((prefix & 0x40) == 0x00) {
                    if ((prefix & 0x20) == 0x00) {
                        //100 - zeros [1-32]
                        decoded += uint8(prefix & ~PF_TYPE2_MASK) + 1;
                        index += 1;
                    } else {
                        //101 - zero padded bytes (to 32) [1-32 num bytes]
                        decoded += 32;
                        index += 32 - uint8(prefix & ~PF_TYPE2_MASK);
                    }
                } else {
                    if ((prefix & 0x20) == 0x00) {
                        //110 - regular bytes [1-32 num bytes]
                        decoded += uint8(prefix & ~PF_TYPE2_MASK) + 1;
                        index += uint8(prefix & ~PF_TYPE2_MASK) + 2;
                    } else {
                        //111 - compressed decimal number
                        uint8 size = uint8(prefix >> 3) & 0x03;
                        if (size == 3) decoded += 32;
                        else if (size == 2) decoded += 16;
                        else decoded += (size * 4) + 4;

                        uint8 precision = uint8(prefix & 0x07);
                        if (precision < 4) index += precision + 3;
                        else if (precision < 6) index += ((precision - 4) * 2) + 8;
                        else index += ((precision - 6) * 4) + 14;
                    }
                }
            }
        }
        return decoded;
    }
}

/*
 * Gets the size of the encoded data with the given prefix
 */
function encodeSize(bytes1 prefix) pure returns (uint256) {
    unchecked {
        if ((prefix & 0x80) == 0x00) {
            if ((prefix & 0x40) == 0x00) {
                //00x - 1 byte stateful common bytes [0-63]
                return 1;
            } else {
                if ((prefix & 0x20) == 0x00) {
                    //010 - 2 byte stateful common bytes [0-8192]
                    return 2;
                } else {
                    //011 - 4 byte stateful common bytes [0-536870911]
                    return 4;
                }
            }
        } else {
            if ((prefix & 0x40) == 0x00) {
                if ((prefix & 0x20) == 0x00) {
                    //100 - zeros [1-32]
                    return 1;
                } else {
                    //101 - zero padded bytes (to 32) [1-32 num bytes]
                    return 32 - uint8(prefix & ~PF_TYPE2_MASK);
                }
            } else {
                if ((prefix & 0x20) == 0x00) {
                    //110 - regular bytes [1-32 num bytes]
                    return uint8(prefix & ~PF_TYPE2_MASK) + 2;
                } else {
                    //111 - compressed decimal number
                    uint8 precision = uint8(prefix & 0x07);
                    if (precision < 4) return precision + 3;
                    if (precision < 6) return ((precision - 4) * 2) + 8;
                    return ((precision - 6) * 4) + 14;
                }
            }
        }
    }
}

/*
 * Gets the decoded size of the encoded data
 */
function tenToThePowerOf(uint8 pow) pure returns (uint256) {
    unchecked {
        uint256 res = 1;
        if (pow >= 64) {
            res *= (10 ** 64);
            pow -= 64;
        }
        if (pow >= 32) {
            res *= (10 ** 32);
            pow -= 32;
        }
        if (pow >= 16) {
            res *= (10 ** 16);
            pow -= 16;
        }
        if (pow >= 8) {
            res *= (10 ** 8);
            pow -= 8;
        }
        if (pow >= 4) {
            res *= (10 ** 4);
            pow -= 4;
        }
        if (pow >= 2) {
            res *= (10 ** 2);
            pow -= 2;
        }
        if (pow >= 1) {
            res *= 10;
        }
        return res;
    }
}
