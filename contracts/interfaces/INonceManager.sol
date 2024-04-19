// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface INonceManager {
    /**
     * Return the nonce for this sender and key.
     *
     * @param sender the account address
     * @param key the unique key that points to the nonce
     * @return nonce the nonce value
     */
    function getNonce(address sender, uint256 key) external view returns (uint256 nonce);

    /**
     * Manually set the nonce of the sender.
     * @dev this method should only be allowed to be called by the currently executing intent standard contract
     *
     * @param sender the account address
     * @param key the unique key that points to the nonce
     * @param nonce the nonce value
     */
    function setNonce(address sender, uint256 key, uint256 nonce) external;
}
