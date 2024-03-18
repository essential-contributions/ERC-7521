// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

/**
 * @dev The data added to the end of byte code is formatted as follows:
 * | byte range | description                                     |
 * |------------|-------------------------------------------------|
 * | 0 - n      | n 32byte long datas to retrieve                 |
 * | n - m      | m 20byte long datas to retrieve                 |
 * | m - o      | o 16byte long datas to retrieve                 |
 * | o - p      | p 8byte long datas to retrieve                  |
 * | p - q      | q 4byte long datas to retrieve                  |
 *
 * note: the offsets to jump directly to each section are set with the placeholders below (ex. _dataIndex32)
 */

/**
 * Generalized data registry which returns data appended to the end of bytecode to be called statically
 */
contract GeneralStaticRegistry is IDataRegistry {
    /**
     * @dev The following values are replaced when deploying the bytecode.
     * These values were picked because they are composed of invalid opcodes.
     */
    uint16 private constant _dataIndex32 = 0xeee0;
    uint16 private constant _dataIndex20 = 0xeee1;
    uint16 private constant _dataIndex16 = 0xeee2;
    uint16 private constant _dataIndex8 = 0xeee3;
    uint16 private constant _dataIndex4 = 0xeee4;
    uint16 private constant _dataOffset32 = 0xeee5;
    uint16 private constant _dataOffset20 = 0xeee6;
    uint16 private constant _dataOffset16 = 0xeee7;
    uint16 private constant _dataOffset8 = 0xeee8;
    uint16 private constant _dataOffset4 = 0xeee9;

    function retrieve(uint256 index) external pure override returns (bytes memory) {
        return _retrieve(index);
    }

    function retrieveBatch(uint256 from, uint256 to) external pure override returns (bytes[] memory) {
        require(to > from, "'to' must be before 'from'");
        bytes[] memory items = new bytes[](to - from);
        for (uint256 i = from; i < to; i++) {
            items[i - from] = _retrieve(i);
        }
        return items;
    }

    function length() external pure override returns (uint256) {
        return _dataIndex4;
    }

    function _retrieve(uint256 index) private pure returns (bytes memory) {
        unchecked {
            if (index < _dataIndex32) {
                uint256 offset = _dataOffset32 + index * 32;
                bytes memory data = new bytes(32);
                assembly ("memory-safe") {
                    codecopy(add(data, 0x20), offset, 32)
                }
                return data;
            } else if (index < _dataIndex20) {
                uint256 offset = _dataOffset20 + index * 20;
                bytes memory data = new bytes(20);
                assembly ("memory-safe") {
                    codecopy(add(data, 0x20), offset, 20)
                }
                return data;
            } else if (index < _dataIndex16) {
                uint256 offset = _dataOffset16 + index * 16;
                bytes memory data = new bytes(16);
                assembly ("memory-safe") {
                    codecopy(add(data, 0x20), offset, 16)
                }
                return data;
            } else if (index < _dataIndex8) {
                uint256 offset = _dataOffset8 + index * 8;
                bytes memory data = new bytes(8);
                assembly ("memory-safe") {
                    codecopy(add(data, 0x20), offset, 8)
                }
                return data;
            } else if (index < _dataIndex4) {
                uint256 offset = _dataOffset4 + index * 4;
                bytes memory data = new bytes(4);
                assembly ("memory-safe") {
                    codecopy(add(data, 0x20), offset, 4)
                }
                return data;
            }
            return "";
        }
    }
}
