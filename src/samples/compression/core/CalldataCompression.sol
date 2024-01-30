// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

uint256 constant DICTIONARY_L1_SIZE = 32 + 1024;
uint256 constant DICTIONARY_L1_LENGTHS_OFFSET = 32;
uint256 constant DICTIONARY_L1_DATA_OFFSET = 32 + 32;

/**
 * Three tiered dictionary compression
 *   L1 -> held in memory
 *   L2 -> referrenced from set external contract via static code
 *   L3 -> referrenced from set external contract via dynamic storage
 *
 * Encoding Prefixes
 *   000 - 1 byte dynamic dictionary [1-32] (items to put in storage)
 *   001 - 1 byte closed stateful dictionary [1-32] (items specific to particular target)
 *   010 - 2 byte closed stateful dictionary [1-8192] (function selectors, lengths of zeros greater than 64, multiples of 32, etc)
 *   011 - 4 byte stateful dictionary [1-536870912] (addresses, hashes, etc)
 *   100 - zeros [1-32]
 *   101 - zero padded bytes (to 32) [1-32 zeros]
 *   110 - regular bytes [1-32 bytes]
 *   111 - decimal number
 */
abstract contract CalldataCompression {
    address private immutable _target;
    IDataRegistry private immutable _l2Registry;
    IDataRegistry private immutable _l3Registry;
    bytes32 private immutable _l3RegisterFnSel;

    /**
     * Constructor
     */
    constructor(address target, IDataRegistry l2Registry, IDataRegistry l3Registry, bytes4 l3RegisterFnSel) {
        _target = target;
        _l2Registry = l2Registry;
        _l3Registry = l3Registry;
        _l3RegisterFnSel = bytes32(uint256(uint32(l3RegisterFnSel)));
    }

    /**
     * Function to return the static l1 dictionary data
     * @dev this is the one function inheriting contracts must implement to help tailor
     * stateful dictionaries to the intended target
     */
    function staticL1Dictionary() internal pure virtual returns (bytes memory);

    /**
     * Gets the target contract to do calldata compression for
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function target_00aef2() external view returns (address) {
        return _target;
    }

    /**
     * Get the level 1 static dictionary items
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function l1Dictionary_004055() external pure returns (bytes[] memory) {
        bytes memory compressedFormat = staticL1Dictionary();
        bytes[] memory l1Dictionary = new bytes[](32);

        uint256 lengths;
        assembly {
            lengths := mload(add(compressedFormat, 0x20))
        }
        for (uint256 i = 0; i < 32 && (i + 1) < compressedFormat.length; i++) {
            uint256 length;
            assembly {
                length := byte(i, lengths)
            }
            bytes memory data = new bytes(length);
            for (uint256 j = 0; j < length; j++) {
                data[j] = compressedFormat[32 + (i * 32) + j];
            }
            l1Dictionary[i] = data;
        }
        return l1Dictionary;
    }

    /**
     * Get the level 2 static dictionary items in pages of 1024
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function l2Dictionary_010b59(uint256 page) external view returns (bytes[] memory) {
        require(page < 8, "Invalid page");
        return _l2Registry.retrieveBatch(page * 1024, (page + 1) * 1024);
    }

    /**
     * Get the level 2 dictionary registry contract
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function l2Registry_00233a() external view returns (IDataRegistry) {
        return _l2Registry;
    }

    /**
     * Get the level 3 dictionary registry contract
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function l3Registry_00e25a() external view returns (IDataRegistry) {
        return _l3Registry;
    }

    /**
     * Get the register function selector for the level 3 dictionary registry contract
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function l3RegisterFnSel_0547f2() external view returns (bytes4) {
        return bytes4(uint32(uint256(_l3RegisterFnSel)));
    }

    /**
     * Function to check decompression without making a call to the target
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function decompress_016ca1(bytes calldata data) external view returns (bytes memory) {
        return decompress(data);
    }

    /**
     * Compressed calldata is received here which then gets decompressed and sent to the target contract
     */
    fallback() external {
        address target = _target;
        bytes calldata data;
        assembly {
            data.offset := 0
            data.length := calldatasize()
        }
        bytes memory decompressed = decompress(data);
        assembly {
            if iszero(call(gas(), target, callvalue(), add(decompressed, 0x20), mload(decompressed), 0, 0)) {
                revert(0, 0)
            }
        }
    }

    /**
     * Compressed calldata is received here which then gets decompressed and sent to the target contract
     */
    function decompress(bytes calldata data) private view returns (bytes memory result) {
        address l2Reg = address(_l2Registry);
        address l3Reg = address(_l3Registry);
        bytes memory staticL1Dict = staticL1Dictionary();

        assembly ("memory-safe") {
            let dataIdx := data.offset
            let outIdx := mload(0x40)

            //first decode the dynamic l1 dictionary
            let staticL1 := add(staticL1Dict, 0x20)
            let dynamicL1 := outIdx
            {
                let dataLengths := 0
                let length := byte(0, calldataload(dataIdx))
                dataIdx := add(dataIdx, 1)
                outIdx := add(outIdx, 0x20)
                let end := add(outIdx, mul(length, 0x20))
                for {} lt(outIdx, end) {} {
                    let s := outIdx
                    dataIdx, outIdx := decode(dataIdx, outIdx, dynamicL1, staticL1, l2Reg, l3Reg)
                    dataLengths := add(shl(8, dataLengths), sub(outIdx, s))
                    outIdx := add(s, 0x20)
                }
                dataLengths := shl(shl(3, sub(32, length)), dataLengths)
                mstore(dynamicL1, dataLengths)
            }

            //start decoding data
            result := outIdx
            outIdx := add(result, 0x20)
            let end := add(data.offset, data.length)
            for {} lt(dataIdx, end) {} { dataIdx, outIdx := decode(dataIdx, outIdx, dynamicL1, staticL1, l2Reg, l3Reg) }

            //prep data for output
            mstore(result, sub(outIdx, add(result, 0x20))) //set result length
            mstore(outIdx, 0) //clean up the end of the array from possible excessive copies
            mstore(0x40, add(outIdx, 0x20)) //set the free memory pointer to just after the result

            //function to decode an item
            function decode(in, out, dl1, sl1, l2, l3) -> in2, out2 {
                let cd := calldataload(in)
                let op := shr(253, cd)
                cd := shr(3, shl(3, cd))

                switch op
                case 0 {
                    //000 - dynamic dictionary [0-31] (items to put in storage)
                    let i := shr(248, cd)
                    mstore(out, mload(add(dl1, mul(add(i, 1), 0x20))))
                    in2 := add(in, 1)
                    out2 := add(out, byte(i, mload(dl1)))
                }
                case 1 {
                    //001 - 1 byte closed stateful dictionary [0-31] (items specific to particular target)
                    let i := shr(248, cd)
                    mstore(out, mload(add(sl1, mul(add(i, 1), 0x20))))
                    in2 := add(in, 1)
                    out2 := add(out, byte(i, mload(sl1)))
                }
                case 2 {
                    //010 - 2 byte closed stateful dictionary [0-8192] (function selectors, lengths of zeros greater than 64, multiples of 32, etc)
                    if l2 {
                        let i := shr(240, cd)
                        mstore(0x00, 0x000000000000000000000000000000000000000000000000000000008f88708b)
                        mstore(0x20, i)
                        if iszero(staticcall(gas(), l2, 28, 36, 0x00, 0x40)) { revert(0, 0) }
                        returndatacopy(out, 0x40, 32)
                        out2 := add(out, mload(0x20))
                    }
                    in2 := add(in, 2)
                }
                case 3 {
                    //011 - 4 byte stateful dictionary [0-536870911] (addresses, hashes, etc)
                    if l3 {
                        let i := shr(224, cd)
                        mstore(0x00, 0x000000000000000000000000000000000000000000000000000000008f88708b)
                        mstore(0x20, i)
                        if iszero(staticcall(gas(), l3, 28, 36, 0x00, 0x40)) { revert(0, 0) }
                        returndatacopy(out, 0x40, 32)
                        out2 := add(out, mload(0x20))
                    }
                    in2 := add(in, 4)
                }
                case 4 {
                    //100 - zeros [1-32]
                    let nz := add(byte(0, cd), 1)
                    in2 := add(in, 1)
                    out2 := add(out, nz)
                }
                case 5 {
                    //101 - zero padded bytes (to 32) [1-32 zeroes]
                    let nz := add(byte(0, cd), 1)
                    let val := shr(shl(3, nz), calldataload(add(in, 1)))
                    mstore(out, val)
                    in2 := add(in, sub(33, nz))
                    out2 := add(out, 32)
                }
                case 6 {
                    //110 - regular bytes [1-32 bytes]
                    let nb := add(byte(0, cd), 1)
                    mstore(out, calldataload(add(in, 1)))
                    in2 := add(in, add(nb, 1))
                    out2 := add(out, nb)
                    mstore(out2, 0)
                }
                case 7 {
                    //111 - decimal number
                    let b := byte(0, cd)
                    let p := and(b, 0x07) //precision
                    switch p
                    case 0 {
                        //1byte precision
                        in2 := add(in, 3)
                        let n := shr(248, shl(8, cd))
                        let m := shr(248, shl(16, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 1 {
                        //2byte precision
                        in2 := add(in, 4)
                        let n := shr(240, shl(8, cd))
                        let m := shr(248, shl(24, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 2 {
                        //3byte precision
                        in2 := add(in, 5)
                        let n := shr(232, shl(8, cd))
                        let m := shr(248, shl(32, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 3 {
                        //4byte precision
                        in2 := add(in, 6)
                        let n := shr(224, shl(8, cd))
                        let m := shr(248, shl(40, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 4 {
                        //6byte precision
                        in2 := add(in, 8)
                        let n := shr(208, shl(8, cd))
                        let m := shr(248, shl(56, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 5 {
                        //8byte precision
                        in2 := add(in, 10)
                        let n := shr(192, shl(8, cd))
                        let m := shr(248, shl(72, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 6 {
                        //12byte precision
                        in2 := add(in, 14)
                        let n := shr(160, shl(8, cd))
                        let m := shr(248, shl(104, cd))
                        p := mul(n, tenpow(m))
                    }
                    case 7 {
                        //16byte precision
                        in2 := add(in, 18)
                        let n := shr(128, shl(8, cd))
                        let m := shr(248, shl(136, cd))
                        p := mul(n, tenpow(m))
                    }

                    let s := and(shr(3, b), 0x03) //size
                    switch s
                    case 3 {
                        //32byte size
                        mstore(out, p)
                        out2 := add(out, 32)
                    }
                    case 2 {
                        //16byte size
                        mstore(out, shl(128, p))
                        out2 := add(out, 16)
                    }
                    case 1 {
                        //8byte size
                        mstore(out, shl(192, p))
                        out2 := add(out, 8)
                    }
                    case 0 {
                        //4byte size
                        mstore(out, shl(224, p))
                        out2 := add(out, 4)
                    }
                }
            }

            //function to get powers of 10
            function tenpow(pow) -> res {
                res := 1
                if iszero(lt(pow, 64)) {
                    res := mul(res, 10000000000000000000000000000000000000000000000000000000000000000) // 10 ** 64
                    pow := sub(pow, 64)
                }
                if iszero(lt(pow, 32)) {
                    res := mul(res, 100000000000000000000000000000000) // 10 ** 32
                    pow := sub(pow, 32)
                }
                if iszero(lt(pow, 16)) {
                    res := mul(res, 10000000000000000) // 10 ** 16
                    pow := sub(pow, 16)
                }
                if iszero(lt(pow, 8)) {
                    res := mul(res, 100000000) // 10 ** 8
                    pow := sub(pow, 8)
                }
                if iszero(lt(pow, 4)) {
                    res := mul(res, 10000) // 10 ** 4
                    pow := sub(pow, 4)
                }
                if iszero(lt(pow, 2)) {
                    res := mul(res, 100) // 10 ** 2
                    pow := sub(pow, 2)
                }
                if iszero(lt(pow, 1)) { res := mul(res, 10) }
            }
        }
    }
}
