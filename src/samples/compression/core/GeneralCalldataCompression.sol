// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

uint8 constant VERSION = 0x00;

/**
 * @dev The data added to the end of byte code is formatted as follows:
 * | byte range | byte size | description                                                 |
 * |------------|-----------|-------------------------------------------------------------|
 * | 0-20       | 20        | adress of the target contract                               |
 * | 20-1044    | 1024      | 32x32 datas to retrieve for the L1 static dictionary        |
 * | 1044-1076  | 32        | byte lengths of the 32 datas in the L1 static dictionary    |
 * | 1076-1236  | 160       | 8x20 addresses of the L2 registries (the registry pages)    |
 * | 1236-1256  | 20        | adress of the L3 registry                                   |
 * | 1256-1260  | 4         | function selector to register new data to the L3 registry   |
 *
 * note: the offset to jump directly to this data is set with the placeholders below (ex. _targetOffset)
 */

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
contract GeneralCalldataCompression {
    /**
     * @dev The following values are replaced when deploying the bytecode.
     */
    uint16 private constant _targetOffset = 0xeee0;
    uint16 private constant _l1DictionaryOffset = 0xeee1;
    uint16 private constant _l1DictLengthsOffset = 0xeee2;
    uint16 private constant _l2RegistriesOffset = 0xeee3;
    uint16 private constant _l3RegistryOffset = 0xeee4;

    /**
     * Gets the contract version
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function version_0511d9() external pure returns (uint8) {
        return VERSION;
    }

    /**
     * Function to check decompression without making a call to the target
     * @dev this function was specifically named to result in a selector that will not collide
     * with any compressed data (starts with 0xff00)
     */
    function decompress_0076ce(bytes calldata data) external view returns (bytes memory) {
        return decompress(data);
    }

    /**
     * Compressed calldata is received here which then gets decompressed and sent to the target contract
     */
    fallback() external {
        bytes calldata data;
        uint256 targetAddress;
        assembly ("memory-safe") {
            data.offset := 0
            data.length := calldatasize()
            codecopy(0x00, _targetOffset, 20)
            targetAddress := shr(96, mload(0x00))
        }
        address target = address(uint160(targetAddress));
        bytes memory decompressed = decompress(data);
        assembly ("memory-safe") {
            if iszero(call(gas(), target, callvalue(), add(decompressed, 32), mload(decompressed), 0, 0)) {
                revert(0, 0)
            }
        }
    }

    /**
     * Compressed calldata is received here which then gets decompressed and sent to the target contract
     */
    function decompress(bytes calldata data) private view returns (bytes memory result) {
        assembly ("memory-safe") {
            let dataIdx := data.offset
            let outIdx := mload(0x40)

            //first decode the dynamic l1 dictionary
            let dynamicL1 := outIdx
            {
                let dataLengths := 0
                let length := byte(0, calldataload(dataIdx))
                dataIdx := add(dataIdx, 1)
                outIdx := add(outIdx, 32)
                let end := add(outIdx, mul(length, 32))
                for {} lt(outIdx, end) {} {
                    let s := outIdx
                    dataIdx, outIdx := decode(dataIdx, outIdx, dynamicL1)
                    dataLengths := add(shl(8, dataLengths), sub(outIdx, s))
                    outIdx := add(s, 32)
                }
                dataLengths := shl(shl(3, sub(32, length)), dataLengths)
                mstore(dynamicL1, dataLengths)
            }

            //start decoding data
            result := outIdx
            outIdx := add(result, 32)
            let end := add(data.offset, data.length)
            for {} lt(dataIdx, end) {} { dataIdx, outIdx := decode(dataIdx, outIdx, dynamicL1) }

            //prep data for output
            mstore(result, sub(outIdx, add(result, 32))) //set result length
            mstore(outIdx, 0) //clean up the end of the array from possible excessive copies
            mstore(0x40, add(outIdx, 32)) //set the free memory pointer to just after the result

            //function to decode an item
            function decode(in, out, dl1) -> in2, out2 {
                let cd := calldataload(in)
                let op := shr(253, cd)
                cd := shr(3, shl(3, cd))

                switch op
                case 0 {
                    //000 - dynamic dictionary [0-31] (items to put in storage)
                    let i := shr(248, cd)
                    mstore(out, mload(add(dl1, mul(add(i, 1), 32))))
                    in2 := add(in, 1)
                    out2 := add(out, byte(i, mload(dl1)))
                }
                case 1 {
                    //001 - 1 byte closed stateful dictionary [0-31] (items specific to particular target)
                    let i := shr(248, cd)
                    codecopy(out, add(_l1DictionaryOffset, mul(i, 32)), 32)
                    in2 := add(in, 1)
                    codecopy(0x00, _l1DictLengthsOffset, 32)
                    out2 := add(out, byte(i, mload(0x00)))
                }
                case 2 {
                    //010 - 2 byte closed stateful dictionary [0-8192] (function selectors, lengths of zeros greater than 64, multiples of 32, etc)
                    let i := shr(240, cd)
                    let ri := shr(10, i)
                    codecopy(0x00, add(_l2RegistriesOffset, mul(ri, 20)), 20)
                    let l2 := shr(96, mload(0x00))
                    if l2 {
                        mstore(0x00, 0x000000000000000000000000000000000000000000000000000000008f88708b)
                        mstore(0x20, sub(i, shl(10, ri)))
                        if iszero(staticcall(gas(), l2, 28, 36, 0x00, 0x40)) { revert(0, 0) }
                        returndatacopy(out, 0x40, 32)
                        out2 := add(out, mload(0x20))
                    }
                    in2 := add(in, 2)
                }
                case 3 {
                    //011 - 4 byte stateful dictionary [0-536870911] (addresses, hashes, etc)
                    codecopy(0x00, _l3RegistryOffset, 20)
                    let l3 := shr(96, mload(0x00))
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
