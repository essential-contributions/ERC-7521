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
     * Gets the balance of a given asset.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     */
    function balanceOf(AssetType assetType, address assetContract, uint256 assetId) public view returns (uint256) {
        return _balanceOf(assetType, assetContract, assetId, address(this));
    }

    /**
     * Transfers the given asset.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param to the address to send the assets to.
     * @param amount the amount to release.
     */
    function transfer(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external
        onlyFromEntryPointSolutionExecuting
    {
        require(_balanceOf(assetType, assetContract, assetId, address(this)) >= amount, "insufficient transfer balance");
        _transfer(assetType, assetContract, assetId, address(this), to, amount);
    }

    /**
     * Transfers all of the given asset.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param to the address to send the assets to.
     */
    function transferAll(AssetType assetType, address assetContract, uint256 assetId, address to)
        external
        onlyFromEntryPointSolutionExecuting
    {
        uint256 amount = _balanceOf(assetType, assetContract, assetId, address(this));
        _transfer(assetType, assetContract, assetId, address(this), to, amount);
    }

    /**
     * Sets unlimited approval for the token to an operator.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param operator the account being granted approval.
     * @param approved flag indicating setting or removing approval.
     */
    function setApprovalForAll(
        AssetType assetType,
        address assetContract,
        uint256 assetId,
        address operator,
        bool approved
    ) external onlyFromEntryPointSolutionExecuting {
        _setApprovalForAll(assetType, assetContract, assetId, operator, approved);
    }

    /**
     * Execute a transaction as part of an intent solution.
     * @param target The address of the contract to execute the transaction on.
     * @param value The amount of ether (in wei) to attach to the transaction.
     * @param data The data containing the function selector and parameters to be executed on the target contract.
     */
    function execute(address target, uint256 value, bytes calldata data) external onlyFromEntryPointSolutionExecuting {
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
    function delegate(address target, bytes calldata data) external onlyFromEntryPointSolutionExecuting {
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
