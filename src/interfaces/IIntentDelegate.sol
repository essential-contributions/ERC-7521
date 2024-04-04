// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface IIntentDelegate {
    /**
     * Make a call delegated through an intent standard.
     *
     * @dev Must validate entrypoint is currently executing and intent for the owner
     * and caller is the intent standard that the entry point is currently executing for.
     * @param data calldata.
     */
    function generalizedIntentDelegateCall(bytes memory data) external;
}
