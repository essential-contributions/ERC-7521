// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// solhint-disable no-inline-assembly

/**
 * Utility functions helpful when making different kinds of contract calls in Solidity.
 * note: this library has been modified from it's original version so that "getReturnData"
 * doesn't take in a max length and instead there is a new function called "getReturnDataSize"
 * to allow for manually overflow checking and custom error throwing by the application
 * using this library. The function "callAndRevert" was modified with an added "txGas"
 * parameter. The function "getRevertReasonMax" was added to get just the reason string from
 * a revert or require. The function "getReturnDataMax" was added to allow specifying an offset
 * as well as a max length when fetching return data.
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
    function getReturnDataMax(uint256 offset, uint256 maxLen) internal pure returns (bytes memory returnData) {
        assembly {
            let len := returndatasize()
            if gt(len, offset) {
                len := sub(len, offset)
                if gt(len, maxLen) { len := maxLen }
                let ptr := mload(0x40)
                mstore(0x40, add(ptr, add(len, 0x20)))
                mstore(ptr, len)
                returndatacopy(add(ptr, 0x20), offset, len)
                returnData := ptr
            }
        }
    }

    // get revert reason from last call or calldelegate
    function getRevertReasonMax(uint256 maxLen) internal pure returns (bytes memory returnData) {
        returnData = getReturnDataMax(0x44, maxLen);
    }

    // revert with explicit byte array (probably reverted info from call)
    function revertWithData(bytes memory returnData) internal pure {
        assembly {
            revert(add(returnData, 32), mload(returnData))
        }
    }

    function callAndRevert(address to, bytes memory data, uint256 txGas, uint256 maxLen) internal {
        bool success = call(to, 0, data, txGas);
        if (!success) {
            revertWithData(getReturnDataMax(0, maxLen));
        }
    }
}

library RevertReason {
    // remove the trailing paddings from a revert reason
    function revertReasonWithoutPadding(bytes memory data) internal pure returns (bytes memory) {
        uint256 paddingStartIndex = data.length - 1;
        while (data[paddingStartIndex] == 0) {
            paddingStartIndex = paddingStartIndex - 1;
        }

        bytes memory reason = new bytes(paddingStartIndex + 1);

        for (uint256 i = 0; i <= paddingStartIndex; i++) {
            reason[i] = data[i];
        }
        return reason;
    }
}
