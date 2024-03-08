// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDataRegistry} from "../interfaces/IDataRegistry.sol";

/**
 * Simple static dictionary for general calldata compression
 */
contract PublicStorageRegistry is IDataRegistry {
    address private _owner;
    uint256 private _registrationFee;
    uint256 private _length;
    mapping(uint256 => bytes32) public _entries;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RegistrationFeeSet(uint256 indexed newFee, uint256 indexed previousFee);
    event DataReRegistered(uint256 indexed index, bytes data);

    constructor() {
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    //////////////////////
    // Public Functions //
    //////////////////////

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

    function register(address item) external payable returns (uint256) {
        require(_length < uint256(2 ** 32), "Registry is full");
        require(item != address(0), "Cannot register the zero address");
        require(msg.value >= _registrationFee, "Insufficient registration fee");

        uint256 index = _length;
        _entries[index] = bytes32(uint256(uint160(item)));
        _length = _length + 1;

        emit DataRegistered(index, _retrieve(index));
        return index;
    }

    function registrationFee() external view returns (uint256) {
        return _registrationFee;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    /////////////////////
    // Admin Functions //
    /////////////////////

    function renounceOwnership() public onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        _transferOwnership(newOwner);
    }

    function setRegistrationFee(uint256 newFee) public onlyOwner {
        uint256 previousFee = _registrationFee;
        _registrationFee = newFee;
        emit RegistrationFeeSet(newFee, previousFee);
    }

    function overrideRegistry(uint256 index, bytes32 value) public onlyOwner {
        require(index < _length, "Invalid index");
        _entries[index] = value;
        emit DataReRegistered(index, _retrieve(index));
    }

    function withdrawFees(address payable to, uint256 amount) public onlyOwner {
        to.transfer(amount);
    }

    ///////////////////////
    // Private Functions //
    ///////////////////////

    function _retrieve(uint256 index) private view returns (bytes memory) {
        bytes32 item = _entries[index];
        bytes memory ret = new bytes(32);
        assembly ("memory-safe") {
            mstore(add(ret, 0x20), item)
        }
        return ret;
    }

    function _checkOwner() private view {
        require(_owner == msg.sender, "Caller is not the owner");
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
