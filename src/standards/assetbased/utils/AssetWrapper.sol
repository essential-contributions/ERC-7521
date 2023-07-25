// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

/**
 * List of supported asset types.
 */
enum AssetType {
    ETH,
    ERC20,
    ERC721,
    ERC721_ID,
    ERC1155,
    COUNT
}

/**
 * Gets the balance of a given asset.
 * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
 * @param assetContract the contract that controls the asset.
 * @param assetId the identifier for a specific asset.
 * @param owner the owner to check the balance of.
 */
function _balanceOf(AssetType assetType, address assetContract, uint256 assetId, address owner)
    view
    returns (uint256)
{
    if (assetType == AssetType.ETH) {
        return owner.balance;
    } else if (assetType == AssetType.ERC20) {
        return IERC20(assetContract).balanceOf(owner);
    } else if (assetType == AssetType.ERC721) {
        return IERC721(assetContract).balanceOf(owner);
    } else if (assetType == AssetType.ERC721_ID) {
        if (owner == IERC721(assetContract).ownerOf(assetId)) {
            return 1;
        }
        return 0;
    } else if (assetType == AssetType.ERC1155) {
        return IERC1155(assetContract).balanceOf(owner, assetId);
    }
    return 0;
}

/**
 * Transfers the given asset.
 * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
 * @param assetContract the contract that controls the asset.
 * @param assetId the identifier for a specific asset.
 * @param caller the caller address.
 * @param to the address to send the assets to.
 * @param amount the amount to release.
 */
function _transfer(
    AssetType assetType,
    address assetContract,
    uint256 assetId,
    address caller,
    address to,
    uint256 amount
) {
    if (assetType == AssetType.ETH) {
        payable(to).transfer(amount);
    } else if (assetType == AssetType.ERC20) {
        IERC20(assetContract).transfer(to, amount);
    } else if (assetType == AssetType.ERC721) {
        // not supported
    } else if (assetType == AssetType.ERC721_ID) {
        // recipient must implement IERC721Receiver-onERC721Received
        IERC721(assetContract).safeTransferFrom(caller, to, assetId);
    } else if (assetType == AssetType.ERC1155) {
        // recipient must implement IERC1155Receiver-onERC1155Received
        IERC1155(assetContract).safeTransferFrom(caller, to, assetId, amount, "");
    }
}

/**
 * Transfers the given asset from a given address.
 * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
 * @param assetContract the contract that controls the asset.
 * @param assetId the identifier for a specific asset.
 * @param from the current assets owner.
 * @param to the address to send the assets to.
 * @param amount the amount to release.
 */
function _transferFrom(
    AssetType assetType,
    address assetContract,
    uint256 assetId,
    address from,
    address to,
    uint256 amount
) {
    if (assetType == AssetType.ETH) {
        // not supported
    } else if (assetType == AssetType.ERC20) {
        IERC20(assetContract).transferFrom(from, to, amount);
    } else if (assetType == AssetType.ERC721) {
        // not supported
    } else if (assetType == AssetType.ERC721_ID) {
        // recipient must implement IERC721Receiver-onERC721Received
        IERC721(assetContract).safeTransferFrom(from, to, assetId);
    } else if (assetType == AssetType.ERC1155) {
        // recipient must implement IERC1155Receiver-onERC1155Received
        IERC1155(assetContract).safeTransferFrom(from, to, assetId, amount, "");
    }
}

/**
 * Sets unlimited approval for the token to an operator.
 * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
 * @param assetContract the contract that controls the asset.
 * @param assetId the identifier for a specific asset.
 * @param operator the account being granted approval.
 * @param approved flag indicating setting or removing approval.
 */
function _setApprovalForAll(
    AssetType assetType,
    address assetContract,
    uint256 assetId,
    address operator,
    bool approved
) {
    if (assetType == AssetType.ETH) {
        // nothing to do
    } else if (assetType == AssetType.ERC20) {
        uint256 amount = approved ? type(uint256).max : 0;
        IERC20(assetContract).approve(operator, amount);
    } else if (assetType == AssetType.ERC721) {
        IERC721(assetContract).setApprovalForAll(operator, approved);
    } else if (assetType == AssetType.ERC721_ID) {
        address to = approved ? operator : 0x0000000000000000000000000000000000000000;
        IERC721(assetContract).approve(to, assetId);
    } else if (assetType == AssetType.ERC1155) {
        IERC1155(assetContract).setApprovalForAll(operator, approved);
    }
}
