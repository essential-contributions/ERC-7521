// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {INonceManager} from "../interfaces/INonceManager.sol";

/**
 * nonce management functionality
 */
abstract contract NonceManager is INonceManager {
    /**
     * The next valid sequence number for a given nonce key.
     */
    mapping(address => mapping(uint256 => uint256)) private _nonceValues;

    /**
     * Return the nonce for this sender and key.
     *
     * @param sender the account address
     * @param key the unique key that points to the nonce
     * @return nonce the nonce value
     */
    function getNonce(address sender, uint256 key) public view override returns (uint256 nonce) {
        return _nonceValues[sender][key];
    }

    /**
     * Return the nonce for this sender and key.
     *
     * @param sender the account address
     * @param key the unique key that points to the nonce
     * @return nonce the nonce value
     */
    function _getNonce(address sender, uint256 key) internal view returns (uint256 nonce) {
        return _nonceValues[sender][key];
    }

    /**
     * Manually set the nonce of the sender.
     *
     * @param sender the account address
     * @param key the unique key that points to the nonce
     * @param nonce the nonce value
     */
    function _setNonce(address sender, uint256 key, uint256 nonce) internal {
        _nonceValues[sender][key] = nonce;
    }
}
