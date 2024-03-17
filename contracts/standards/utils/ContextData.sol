// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

function push(bytes memory context, bytes32 data) pure returns (bytes memory newContext) {
    unchecked {
        uint256 contextLength = context.length;
        newContext = new bytes(contextLength + 32);
        for (uint256 i = 0; i < contextLength; i += 32) {
            assembly {
                mstore(add(newContext, i), mload(add(context, i)))
            }
        }
        assembly {
            mstore(add(add(newContext, 32), contextLength), data)
        }
    }
}

function pushFromCalldata(bytes calldata context, bytes32 data) pure returns (bytes memory newContext) {
    unchecked {
        uint256 contextLength = context.length;
        newContext = new bytes(contextLength + 32);
        if (contextLength > 0) {
            assembly {
                calldatacopy(add(newContext, 32), context.offset, contextLength)
            }
        }
        assembly {
            mstore(add(add(newContext, 32), contextLength), data)
        }
    }
}

function pop(bytes memory context) pure returns (bytes memory newContext, bytes32 data) {
    unchecked {
        uint256 contextLength = context.length - 32;
        newContext = new bytes(contextLength);
        for (uint256 i = 0; i < contextLength; i += 32) {
            assembly {
                mstore(add(newContext, i), mload(add(context, i)))
            }
        }
        assembly {
            data := mload(add(context, contextLength))
        }
    }
}

function popFromCalldata(bytes calldata context) pure returns (bytes memory newContext, bytes32 data) {
    unchecked {
        uint256 contextLength = context.length - 32;
        newContext = new bytes(contextLength);
        if (contextLength > 0) {
            assembly {
                calldatacopy(add(newContext, 32), context.offset, contextLength)
            }
        }
        assembly {
            data := calldataload(add(context.offset, contextLength))
        }
    }
}
