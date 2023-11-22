// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {INonceManager} from "../interfaces/INonceManager.sol";

/**
 * nonce management functionality
 */
abstract contract NonceManager is INonceManager {
    /**
     * The next valid sequence number for a given nonce key.
     */
    mapping(address => mapping(uint256 => uint256)) public nonceValues;

    /**
     * Return the nonce for this sender and key.
     *
     * @param sender the account address
     * @param key the unique key that points to the nonce
     * @return nonce the nonce value
     */
    function getNonce(address sender, uint256 key) public view override returns (uint256 nonce) {
        return nonceValues[sender][key];
    }

    /**
     * Manually set the nonce of the sender.
     * @dev this method should only be allowed to be called by the currently executing intent standard contract
     *
     * @param key the unique key that points to the nonce
     */
    function setNonce(uint256 key, uint256 nonce) public override {
        _setNonce(key, nonce);
    }

    /**
     * Manually set the nonce of the sender.
     * @dev this method should only be allowed to be called by the currently executing intent standard contract
     */
    function _setNonce(uint256 key, uint256 nonce) internal virtual;
}
