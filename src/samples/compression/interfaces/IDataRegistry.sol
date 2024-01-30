// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/**
 * Simple registry that allows retreiving values
 */
interface IDataRegistry {
    event DataRegistered(uint256 indexed index, bytes data);

    function retrieve(uint256 index) external view returns (bytes memory);
    function retrieveBatch(uint256 from, uint256 to) external view returns (bytes[] memory);
    function length() external view returns (uint256);
}
