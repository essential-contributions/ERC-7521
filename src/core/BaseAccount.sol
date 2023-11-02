// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-empty-blocks */
/* solhint-disable private-vars-leading-underscore */

import {IAccount} from "../interfaces/IAccount.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";

/**
 * Basic account implementation.
 * this contract provides the basic logic for implementing the IAccount interface - validateUserIntent
 * specific account implementation should inherit it and provide the account-specific logic
 */
abstract contract BaseAccount is IAccount {
    /**
     * Validate user's signature.
     * subclass doesn't need to override this method. Instead, it should override the specific internal validation methods.
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash)
        external
        view
        virtual
        override
        returns (uint256 result)
    {
        return _validateSignature(intent, intentHash);
    }

    /**
     * validate the signature is valid for this intent.
     * @param intent validate the intent.signature field
     * @param intentHash convenient field: the hash of the intent, to check the signature against
     *          (also hashes the entrypoint and chain id)
     * @return result validation result of this intent
     *      0 - valid signature
     *      1 - signature failure
     */
    function _validateSignature(UserIntent calldata intent, bytes32 intentHash)
        internal
        view
        virtual
        returns (uint256 result);
}
