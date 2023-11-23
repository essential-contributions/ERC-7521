// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {EntryPointTruster} from "../core/EntryPointTruster.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract AbstractAccount is EntryPointTruster, IAccount, IIntentDelegate {
    using ECDSA for bytes32;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    address public owner;

    address private immutable _entryPoint;

    event AccountCreated(IEntryPoint indexed entryPoint, address indexed owner);
    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }

    constructor(IEntryPoint entryPointAddr, address _owner) {
        _entryPoint = address(entryPointAddr);
        owner = _owner;
        emit AccountCreated(entryPointAddr, _owner);
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyFromIntentStandardExecutingForSender
    {
        _call(target, value, data);
        emit Executed(IEntryPoint(_entryPoint), target, value, data);
    }

    /**
     * Execute multiple transactions called from entry point while the entry point is in intent executing state.
     */
    function executeMulti(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        onlyFromIntentStandardExecutingForSender
    {
        require(targets.length == values.length, "invalid multi call inputs");
        require(targets.length == datas.length, "invalid multi call inputs");

        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
            emit Executed(IEntryPoint(_entryPoint), targets[i], values[i], datas[i]);
        }
    }

    /**
     * Make a call delegated through an intent standard.
     *
     * @param data calldata.
     * @return bool delegate call result.
     */
    function generalizedIntentDelegateCall(bytes memory data)
        external
        override
        onlyFromIntentStandardExecutingForSender
        returns (bool)
    {
        bool success = Exec.delegateCall(address(IIntentStandard(msg.sender)), data, gasleft());
        if (!success) {
            bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
            revert(string(reason));
        }
        return success;
    }

    /**
     * Validate user's intent (typically a signature)
     * the entryPoint will continue to execute an intent solution only if this validation call returns successfully.
     * @dev returning 0 indicates signature validated successfully.
     *
     * @param intent validate the intent.signature field
     * @param intentHash convenient field: the hash of the intent, to check the signature against
     *          (also hashes the entrypoint and chain id)
     * @return aggregator (optional) trusted signature aggregator to return if signature fails
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash)
        external
        view
        override
        returns (IAggregator)
    {
        bytes32 hash = intentHash.toEthSignedMessageHash();
        require(owner == hash.recover(intent.signature), "Invalid signature");

        return IAggregator(address(0));
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
