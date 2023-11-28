// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

function getSegmentStandard(bytes calldata data) pure returns (bytes32 standard) {
    assembly {
        standard := calldataload(data.offset)
    }
}

function getSegmentWord(bytes calldata data, uint256 byteOffset) pure returns (bytes32 word) {
    assembly {
        word := calldataload(add(data.offset, byteOffset))
    }
}

function getSegmentBytes(bytes calldata data, uint256 byteOffset, uint256 byteLength) pure returns (bytes memory) {
    bytes memory subset = new bytes(byteLength);
    assembly {
        calldatacopy(add(subset, 32), add(data.offset, byteOffset), byteLength)
    }
    return subset;
}
