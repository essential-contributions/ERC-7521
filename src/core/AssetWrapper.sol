// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AssetType} from "../interfaces/IAssetRelease.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {IERC777} from "openzeppelin/token/ERC777/IERC777.sol";
import {IERC1155} from "openzeppelin/token/ERC1155/IERC1155.sol";

/**
 * Utility functions helpful when working with AssetCurve structs and asset interactions.
 */
library AssetWrapper {
    /**
     * Gets the balance of a given asset.
     * @param assetType the type of asset (ETH, ERC-20, ERC721, etc).
     * @param assetContract the contract that controls the asset.
     * @param assetId the identifier for a specific asset.
     * @param owner the owner to check the balance of.
     */
    function balanceOf(AssetType assetType, address assetContract, uint256 assetId, address owner)
        public
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
        } else if (assetType == AssetType.ERC777) {
            return IERC777(assetContract).balanceOf(owner);
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
     * @param from the current assets owner.
     * @param to the address to send the assets to.
     * @param amount the amount to release.
     */
    function transferFrom(
        AssetType assetType,
        address assetContract,
        uint256 assetId,
        address from,
        address to,
        uint256 amount
    ) public {
        if (assetType == AssetType.ETH) {
            payable(to).transfer(amount);
        } else if (assetType == AssetType.ERC20) {
            IERC20 erc20 = IERC20(assetContract);
            erc20.transferFrom(from, to, amount);
        } else if (assetType == AssetType.ERC721) {
            // not supported
        } else if (assetType == AssetType.ERC721_ID) {
            // recipient must implement IERC721Receiver-onERC721Received
            IERC721 erc721 = IERC721(assetContract);
            erc721.safeTransferFrom(from, to, assetId);
        } else if (assetType == AssetType.ERC777) {
            // recipient must implement ERC777TokensRecipient interface via ERC-1820
            IERC777 erc777 = IERC777(assetContract);
            erc777.send(to, amount, "");
        } else if (assetType == AssetType.ERC1155) {
            // recipient must implement IERC1155Receiver-onERC1155Received
            IERC1155 erc1155 = IERC1155(assetContract);
            erc1155.safeTransferFrom(from, to, assetId, amount, "");
        }
    }
}
