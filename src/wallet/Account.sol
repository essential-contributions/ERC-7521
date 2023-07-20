// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseAccount} from "../core/BaseAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {_packValidationData} from "../core/Helpers.sol";
import {TokenCallbackHandler} from "./TokenCallbackHandler.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract Account is BaseAccount, TokenCallbackHandler {
    using ECDSA for bytes32;

    address public owner;

    IEntryPoint private immutable _entryPoint;

    event AccountCreated(IEntryPoint indexed entryPoint, address indexed owner);
    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    constructor(IEntryPoint anEntryPoint, address _owner) {
        _entryPoint = anEntryPoint;
        owner = _owner;
        emit AccountCreated(anEntryPoint, _owner);
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address _target, uint256 _value, bytes calldata _data) external {
        _requireFromEntryPoint();
        _requireIntentExecuting();
        _call(_target, _value, _data);
        emit Executed(_entryPoint, _target, _value, _data);
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserIntent calldata userInt, bytes32 userIntHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userIntHash.toEthSignedMessageHash();
        if (owner != hash.recover(userInt.signature)) {
            return _packValidationData(true, uint48(userInt.timestamp), 0);
        }
        return _packValidationData(false, uint48(userInt.timestamp), 0);
    }

    /**
     * Call and handle result.
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    receive() external payable {}
}
