// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IAggregator} from "./IAggregator.sol";
import {UserIntent} from "./UserIntent.sol";

interface IAccount {
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
        returns (IAggregator aggregator);
}
