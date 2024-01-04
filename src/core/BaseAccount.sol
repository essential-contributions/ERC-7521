// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {EntryPointTruster} from "../core/EntryPointTruster.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";

abstract contract BaseAccount is EntryPointTruster, IAccount, IIntentDelegate {
    uint256 private constant _REVERT_REASON_MAX_LEN = 2048;
    address private immutable _entryPoint;

    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }

    constructor(IEntryPoint entryPointAddr) {
        _entryPoint = address(entryPointAddr);
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
        bool success = Exec.delegateCall(address(msg.sender), data, gasleft());
        if (!success) {
            bytes memory reason = Exec.getRevertReasonMax(_REVERT_REASON_MAX_LEN);
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
        virtual
        returns (IAggregator aggregator);
}
