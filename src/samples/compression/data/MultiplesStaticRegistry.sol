// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

contract MultiplesStaticRegistry is IDataRegistry {
    uint16 private constant _numMultiplesOf32 = 1024;

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
        return uint256(_numMultiplesOf32);
    }

    function _retrieve(uint256 index) private pure returns (bytes memory) {
        unchecked {
            if (index < uint256(_numMultiplesOf32)) return abi.encodePacked(uint256(0x0100 + (index << 5)));
            return "";
        }
    }
}
