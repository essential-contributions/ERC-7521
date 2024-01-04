// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseAccount} from "../core/BaseAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract AbstractAccount is BaseAccount, Ownable {
    using ECDSA for bytes32;

    uint256 private constant _REVERT_REASON_MAX_LEN = 2048;

    event AccountCreated(IEntryPoint indexed entryPoint, address indexed owner);

    constructor(IEntryPoint entryPointAddr, address ownerAddr) BaseAccount(entryPointAddr) Ownable() {
        _transferOwnership(ownerAddr);
        emit AccountCreated(entryPointAddr, ownerAddr);
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
        require(owner() == hash.recover(intent.signature), "Invalid signature");

        return IAggregator(address(0));
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyFromIntentStandardExecutingForSender
    {
        _call(target, value, data);
        emit Executed(entryPoint(), target, value, data);
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
            emit Executed(entryPoint(), targets[i], values[i], datas[i]);
        }
    }

    /**
     * Call and handle result.
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        bool success = Exec.call(target, value, data, gasleft());
        if (!success) {
            Exec.revertWithData(Exec.getReturnDataMax(0, _REVERT_REASON_MAX_LEN));
        }
    }

    /**
     * Default receive function.
     */
    receive() external payable {}
}
