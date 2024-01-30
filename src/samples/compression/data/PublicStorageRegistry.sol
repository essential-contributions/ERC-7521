// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

/**
 * Simple static dictionary for general calldata compression
 */
contract PublicStorageRegistry is IDataRegistry {
    uint256 private _length;
    mapping(uint256 => bytes32) public _entries;

    function retrieve(uint256 index) external view override returns (bytes memory) {
        return _retrieve(index);
    }

    function retrieveBatch(uint256 from, uint256 to) external view override returns (bytes[] memory) {
        require(to > from, "'to' must be before 'from'");
        bytes[] memory items = new bytes[](to - from);
        for (uint256 i = from; i < to; i++) {
            items[i - from] = _retrieve(i);
        }
        return items;
    }

    function length() external view override returns (uint256) {
        return _length;
    }

    function register(address item) external returns (uint256) {
        uint256 index = _length;
        _entries[index] = bytes32(uint256(uint160(item)));
        _length = _length + 1;

        emit DataRegistered(index, _retrieve(index));
        return index;
    }

    function _retrieve(uint256 index) private view returns (bytes memory) {
        bytes32 item = _entries[index];
        bytes memory ret = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(ret, 0x20), item)
        }
        return ret;
    }
}
