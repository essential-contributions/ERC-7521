// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Ownable} from "openzeppelin/access/Ownable.sol";

//TODO: could be simplified as a single registry map where anyone can claim any unused index

/*
 * Two byte registry has a special bin for different data lengths
 */
uint256 constant MAX_ONE_BYTE = 64;
uint256 constant MAX_TWO_BYTE = 6144;
uint256 constant MAX_FOUR_BYTE = 536870912;
uint256 constant MAX_FN_SEL_BIN = 2048;

/*
 * Contract that stores data on-chain to help with compression
 */
contract DataRegistry is Ownable {
    /**
     * Registry mappings
     */
    mapping(uint256 => bytes32) public oneByteRegistry;
    mapping(uint256 => bytes32) public twoByteRegistry;
    mapping(uint256 => bytes32) public fourByteRegistry;
    mapping(uint256 => bytes4) public fnSelRegistry;
    uint256 public oneByteRegistryLength;
    uint256 public twoByteRegistryLength;
    uint256 public fourByteRegistryLength;
    uint256 public fnSelRegistryLength;

    /**
     * Events
     */
    event OneByteRegistryAdd(uint256 indexed index, bytes32 data);
    event TwoByteRegistryAdd(uint256 indexed index, bytes32 data);
    event FourByteRegistryAdd(uint256 indexed index, bytes32 data);
    event FnSelRegistryAdd(uint256 indexed index, bytes4 data);

    /**
     * Constructor
     */
    constructor() Ownable() {
        //nothing to set up
    }

    /**
     * Adds bytes to the single byte encoding registry
     */
    function addOneByteItem(bytes32 data) external onlyOwner {
        uint256 index = oneByteRegistryLength;
        if (index < MAX_ONE_BYTE) {
            oneByteRegistry[index] = data;
            oneByteRegistryLength = index + 1;
            emit OneByteRegistryAdd(index, data);
        }
    }

    /**
     * Adds bytes to the two byte encoding registry
     */
    function addTwoByteItem(bytes32 data) external onlyOwner {
        uint256 index = twoByteRegistryLength;
        if (index < MAX_TWO_BYTE) {
            twoByteRegistry[index] = data;
            twoByteRegistryLength = index + 1;
            emit TwoByteRegistryAdd(index, data);
        }
    }

    /**
     * Adds bytes to the four byte encoding registry
     */
    function addFourByteItem(bytes32 data) external onlyOwner {
        uint256 index = fourByteRegistryLength;
        if (index < MAX_FOUR_BYTE) {
            fourByteRegistry[index] = data;
            fourByteRegistryLength = index + 1;
            emit FourByteRegistryAdd(index, data);
        }
    }

    /**
     * Adds bytes to the function selector encoding registry
     */
    function addFunctionSelector(bytes4 data) external onlyOwner {
        uint256 index = fnSelRegistryLength;
        if (index < MAX_FN_SEL_BIN) {
            fnSelRegistry[index] = data;
            fnSelRegistryLength = index + 1;
            emit FnSelRegistryAdd(index, data);
        }
    }

    /**
     * Gets an item from the registry
     */
    function oneByte(uint256 index) external view returns (bytes32) {
        return oneByteRegistry[index];
    }

    /**
     * Gets an item from the registry
     */
    function twoByte(uint256 index) external view returns (bytes32) {
        return twoByteRegistry[index];
    }

    /**
     * Gets an item from the registry
     */
    function fourByte(uint256 index) external view returns (bytes32) {
        return fourByteRegistry[index];
    }

    /**
     * Gets an item from the registry
     */
    function fnSel(uint256 index) external view returns (bytes4) {
        return fnSelRegistry[index];
    }

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
