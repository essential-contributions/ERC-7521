// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_balanceOf, _transfer, _transferFrom, _setApprovalForAll, AssetType} from "./utils/AssetWrapper.sol";
import {EntryPointTruster} from "../../core/EntryPointTruster.sol";
import {TokenCallbackHandler} from "../../wallet/TokenCallbackHandler.sol";
import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "openzeppelin/token/ERC1155/IERC1155Receiver.sol";

/**
 * Contract that holds assets and allows a trusted EntryPoint to perform certain actions.
 */
abstract contract AssetHolderProxy is EntryPointTruster, IERC721Receiver, IERC1155Receiver, TokenCallbackHandler {
    /**
     * Execute a transaction as part of an intent solution.
     * @param target The address of the contract to execute the transaction on.
     * @param value The amount of ether (in wei) to attach to the transaction.
     * @param data The data containing the function selector and parameters to be executed on the target contract.
     */
    function execute(address target, uint256 value, bytes calldata data) external onlyFromEntryPoint {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /**
     * Execute a transaction as part of an intent solution.
     * @param target The address of the contract to execute the transaction on.
     * @param data The data containing the function selector and parameters to be executed on the target contract.
     */
    function delegate(address target, bytes calldata data) external onlyFromEntryPoint {
        (bool success, bytes memory result) = target.delegatecall(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
