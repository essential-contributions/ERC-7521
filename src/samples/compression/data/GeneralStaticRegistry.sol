// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

/**
 * Simple static dictionary for general calldata compression
 */
contract GeneralStaticRegistry is IDataRegistry {
    address private immutable _staticAddress0;
    address private immutable _staticAddress1;
    address private immutable _staticAddress2;
    address private immutable _staticAddress3;
    address private immutable _staticAddress4;
    address private immutable _staticAddress5;
    address private immutable _staticAddress6;
    address private immutable _staticAddress7;

    constructor(address[] memory staticAddresses) {
        if (staticAddresses.length > 0) _staticAddress0 = staticAddresses[0];
        if (staticAddresses.length > 1) _staticAddress1 = staticAddresses[1];
        if (staticAddresses.length > 2) _staticAddress2 = staticAddresses[2];
        if (staticAddresses.length > 3) _staticAddress3 = staticAddresses[3];
        if (staticAddresses.length > 4) _staticAddress4 = staticAddresses[4];
        if (staticAddresses.length > 5) _staticAddress5 = staticAddresses[5];
        if (staticAddresses.length > 6) _staticAddress6 = staticAddresses[6];
        if (staticAddresses.length > 7) _staticAddress7 = staticAddresses[7];
    }

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

    function length() external pure override returns (uint256) {
        return 8192;
    }

    function _retrieve(uint256 index) private view returns (bytes memory) {
        //TODO: experiment writting in assembly
        unchecked {
            //2 byte multiples of 32
            if (index < 512) return abi.encodePacked(uint256(0x1000 + index * 32));

            //common function selectors
            if (index < 515) {
                if (index == 512) return abi.encodePacked(bytes4(0xb61d27f6));
                if (index == 513) return abi.encodePacked(bytes4(0xa9059cbb));
                if (index == 514) return abi.encodePacked(bytes4(0x18c6051a));
            }

            //common addresses
            if (index < 523) {
                if (index == 515) return abi.encodePacked(uint256(uint160(_staticAddress0)));
                if (index == 516) return abi.encodePacked(uint256(uint160(_staticAddress1)));
                if (index == 517) return abi.encodePacked(uint256(uint160(_staticAddress2)));
                if (index == 518) return abi.encodePacked(uint256(uint160(_staticAddress3)));
                if (index == 519) return abi.encodePacked(uint256(uint160(_staticAddress4)));
                if (index == 520) return abi.encodePacked(uint256(uint160(_staticAddress5)));
                if (index == 521) return abi.encodePacked(uint256(uint160(_staticAddress6)));
                if (index == 522) return abi.encodePacked(uint256(uint160(_staticAddress7)));
            }

            return "";
        }
    }
}
