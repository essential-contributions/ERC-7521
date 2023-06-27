// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable no-inline-assembly

/**
 * Utility functions helpful when making different kinds of contract calls in Solidity.
 * note: this library has been modified from it's original version so that "getReturnData"
 * doesn't take in a max length and instead there is a new function called "getReturnDataSize"
 * to allow for manually overflow checking and custom error throwing by the application
 * using this library.
 */
library Exec {
    function call(address to, uint256 value, bytes memory data, uint256 txGas) internal returns (bool success) {
        assembly {
            success := call(txGas, to, value, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function staticcall(address to, bytes memory data, uint256 txGas) internal view returns (bool success) {
        assembly {
            success := staticcall(txGas, to, add(data, 0x20), mload(data), 0, 0)
        }
    }

    function delegateCall(address to, bytes memory data, uint256 txGas) internal returns (bool success) {
        assembly {
            success := delegatecall(txGas, to, add(data, 0x20), mload(data), 0, 0)
        }
    }

    // get returned data size from last call or calldelegate
    function getReturnDataSize() internal pure returns (uint256 size) {
        assembly {
            size := returndatasize()
        }
    }

    // get returned data from last call or calldelegate
    function getReturnData() internal pure returns (bytes memory returnData) {
        assembly {
            let len := returndatasize()
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, add(len, 0x20)))
            mstore(ptr, len)
            returndatacopy(add(ptr, 0x20), 0, len)
            returnData := ptr
        }
    }

    // get returned data from last call or calldelegate
    function getReturnDataMax(uint256 maxLen) internal pure returns (bytes memory returnData) {
        assembly {
            let len := returndatasize()
            if gt(len, maxLen) { len := maxLen }
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, add(len, 0x20)))
            mstore(ptr, len)
            returndatacopy(add(ptr, 0x20), 0, len)
            returnData := ptr
        }
    }

    // revert with explicit byte array (probably reverted info from call)
    function revertWithData(bytes memory returnData) internal pure {
        assembly {
            revert(add(returnData, 32), mload(returnData))
        }
    }

    function callAndRevert(address to, bytes memory data, uint256 maxLen) internal {
        bool success = call(to, 0, data, gasleft());
        if (!success) {
            revertWithData(getReturnDataMax(maxLen));
        }
    }
}
