// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IIntentDelegate {
    /**
     * Make a call delegated through an intent standard.
     *
     * @dev Must validate entrypoint is currently executing and intent for the owner
     * and caller is the intent standard that the entry point is currently executing for.
     *      Must validate the signature, nonce, etc.
     * @param data calldata.
     * @return bool delegate call result.
     */
    function generalizedIntentDelegateCall(bytes memory data) external returns (bool);
}
