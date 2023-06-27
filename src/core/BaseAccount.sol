// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-empty-blocks */
/* solhint-disable private-vars-leading-underscore */

import {TokenCallbackHandler} from "./TokenCallbackHandler.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {IAssetRelease, AssetType} from "../interfaces/IAssetRelease.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * Basic account implementation.
 * this contract provides the basic logic for implementing the IAccount interface  - validateUserInt
 * specific account implementation should inherit it and provide the account-specific logic
 */
abstract contract BaseAccount is IAccount, IAssetRelease {
    using UserIntentLib for UserIntent;

    /**
     * Return the account nonce.
     * This method returns the next sequential nonce.
     * For a nonce of a specific key, use `entrypoint.getNonce(account, key)`
     */
    function getNonce() public view virtual returns (uint256) {
        return entryPoint().getNonce(address(this), 0);
    }

    /**
     * return the entryPoint used by this account.
     * subclass should return the current entryPoint used by this account.
     */
    function entryPoint() public view virtual returns (IEntryPoint);

    /**
     * Validate user's signature and nonce.
     * subclass doesn't need to override this method. Instead, it should override the specific internal validation methods.
     */
    function validateUserInt(UserIntent calldata userInt, bytes32 userIntHash)
        external
        virtual
        override
        returns (uint256 validationData)
    {
        _requireFromEntryPoint();
        validationData = _validateSignature(userInt, userIntHash);
        _validateNonce(userInt.nonce);
    }

    /**
     * Releases a user's asset(s) to the entryPoint contract.
     */
    // solhint-disable-next-line no-unused-vars
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, uint256 amount)
        external
        virtual
        override
    {
        _requireFromEntryPoint();

        // transfer tokens
        if (assetType == AssetType.ETH) {
            payable(address(entryPoint())).transfer(amount);
        } else if (assetType == AssetType.ERC20) {
            IERC20 erc20 = IERC20(assetContract);
            erc20.transferFrom(address(this), address(entryPoint()), amount);
        } else if (assetType == AssetType.ERC721) {
            //TODO
        } else if (assetType == AssetType.ERC777) {
            //TODO
        } else if (assetType == AssetType.ERC1155) {
            //TODO
        }
    }

    /**
     * ensure the intent comes from the known entrypoint.
     */
    function _requireFromEntryPoint() internal view virtual {
        require(msg.sender == address(entryPoint()), "account: not from EntryPoint");
    }

    /**
     * validate the signature is valid for this intent.
     * @param userInt validate the userInt.signature field
     * @param userIntHash convenient field: the hash of the intent, to check the signature against
     *          (also hashes the entrypoint and chain id)
     * @return validationData signature and time-range of this intent
     *      <20-byte> sigFailed - 0 for valid signature, 1 to mark signature failure
     *      <6-byte> validUntil - last timestamp this intent is valid. 0 for "indefinite"
     *      <6-byte> validAfter - first timestamp this intent is valid
     *      Note that the validation code cannot use block.timestamp (or block.number) directly.
     */
    function _validateSignature(UserIntent calldata userInt, bytes32 userIntHash)
        internal
        virtual
        returns (uint256 validationData);

    /**
     * Validate the nonce of the UserIntent.
     * This method may validate the nonce requirement of this account.
     * e.g.
     * To limit the nonce to use sequenced UserInts only (no "out of order" UserInts):
     *      `require(nonce < type(uint64).max)`
     * For a hypothetical account that *requires* the nonce to be out-of-order:
     *      `require(nonce & type(uint64).max == 0)`
     *
     * The actual nonce uniqueness is managed by the EntryPoint, and thus no other
     * action is needed by the account itself.
     *
     * @param nonce to validate
     *
     * solhint-disable-next-line no-empty-blocks
     */
    function _validateNonce(uint256 nonce) internal view virtual {}
}
