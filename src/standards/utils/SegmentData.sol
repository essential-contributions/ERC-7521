// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

function getSegmentStandard(bytes calldata context) pure returns (bytes32 standard) {
    assembly {
        standard := calldataload(context.offset)
    }
}

function getSegmentWord(bytes calldata context, uint256 byteOffset) pure returns (bytes32 data) {
    assembly {
        data := calldataload(add(context.offset, byteOffset))
    }
}

function getSegmentBytes(bytes calldata context, uint256 byteOffset, uint256 byteLength) pure returns (bytes memory) {
    bytes memory data = new bytes(byteLength);
    assembly {
        calldatacopy(add(data, 32), add(context.offset, byteOffset), byteLength)
    }
    return data;
}
