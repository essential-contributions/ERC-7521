// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IAccount} from "../interfaces/IAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";

/**
 * Basic account implementation.
 * This contract provides the basic logic for implementing the IAccount and IIntentDelegate interface
 * Specific account implementation should inherit it and provide the account-specific logic.
 */
abstract contract BaseAccount is IAccount, IIntentDelegate {
    /**
     * Validate user's intent (typically a signature)
     * @dev returning 0 indicates signature validated successfully.
     *
     * @param intent validate the intent.signature field
     * @param intentHash the hash of the intent, to check the signature against
     * @return aggregator (optional) trusted signature aggregator to return if signature fails
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash)
        external
        view
        virtual
        returns (IAggregator aggregator);

    /**
     * Return the entryPoint used by this account.
     * Subclass should return the current entryPoint used by this account.
     */
    function entryPoint() public view virtual returns (IEntryPoint);

    /**
     * Make a call delegated through an intent standard.
     *
     * @param data calldata
     */
    function generalizedIntentDelegateCall(bytes memory data) external override {
        _requireFromIntentStandardExecutingForSender();
        bool success = Exec.delegateCall(address(msg.sender), data, gasleft());
        if (!success) Exec.forwardRevert(Exec.REVERT_REASON_MAX_LEN);
    }

    /**
     * Ensure the request comes from the known entrypoint.
     */
    function _requireFromEntryPoint() internal view virtual {
        require(msg.sender == address(entryPoint()), "not from account EntryPoint");
    }

    /**
     * Ensure
     * 1. entrypoint is currently executing an intent that was made by this contract.
     * 2. the caller intent standard is the one that the entrypoint is currently executing for.
     */
    function _requireFromIntentStandardExecutingForSender() internal view virtual {
        require(
            entryPoint().verifyExecutingIntentSegmentForStandard(IIntentStandard(msg.sender)),
            "entryPoint not executing intent standard for sender"
        );
    }
}
