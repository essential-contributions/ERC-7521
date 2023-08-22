// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IIntentDelegate {
    /**
     * Make a call delegated through an intent standard.
     *
     * @dev Must validate caller is the entryPoint and that it is currently in the intent executing state.
     *      Must validate the signature, nonce, etc.
     * @param data calldata.
     * @return bool delegate call result.
     */
    function generalizedIntentDelegateCall(bytes memory data) external returns (bool);
}
