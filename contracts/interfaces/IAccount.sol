// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {UserIntent} from "./UserIntent.sol";

interface IAccount {
    /**
     * Validate user's intent (typically a signature)
     * @dev returning 0 indicates signature validated successfully.
     *
     * @param intent validate the intent.signature field
     * @param intentHash the hash of the intent, to check the signature against
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash) external;
}
