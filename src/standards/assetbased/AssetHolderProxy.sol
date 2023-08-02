// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_balanceOf, _transfer, _transferFrom, _setApprovalForAll, AssetType} from "./utils/AssetWrapper.sol";
import {EntryPointTruster} from "../../core/EntryPointTruster.sol";
import {IERC165} from "openzeppelin/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "openzeppelin/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "openzeppelin/token/ERC1155/IERC1155Receiver.sol";

/**
 * Contract that holds assets and allows a trusted EntryPoint to perform certain actions.
 */
abstract contract AssetHolderProxy is EntryPointTruster, IERC721Receiver, IERC1155Receiver {
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

    /**
     * Token receipt and interface support functions.
     */
    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IERC721Receiver).interfaceId || interfaceId == type(IERC1155Receiver).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }
}
