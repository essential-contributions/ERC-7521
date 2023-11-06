// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "./UserIntent.sol";

interface IAccount {
    /**
     * Validate user's intent (typically a signature)
     * the entryPoint will continue to execute an intent solution only if this validation call returns successfully.
     *
     * @param intent validate the intent.signature field
     * @param intentHash convenient field: the hash of the intent, to check the signature against
     *          (also hashes the entrypoint and chain id)
     * @return result validation result of this intent
     *      0 - valid signature
     *      1 - signature failure
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash)
        external
        view
        returns (uint256 result);
}
