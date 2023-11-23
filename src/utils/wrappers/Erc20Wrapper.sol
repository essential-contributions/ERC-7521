// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * Gets the balance of a given asset.
 * @param assetContract the contract that controls the asset.
 * @param owner the owner to check the balance of.
 */
function _balanceOf(address assetContract, address owner) view returns (uint256) {
    return IERC20(assetContract).balanceOf(owner);
}

/**
 * Transfers the given asset.
 * @param assetContract the contract that controls the asset.
 * @param to the address to send the assets to.
 * @param amount the amount to release.
 */
function _transfer(address assetContract, address to, uint256 amount) {
    IERC20(assetContract).transfer(to, amount);
}

/**
 * Transfers the given asset from a given address.
 * @param assetContract the contract that controls the asset.
 * @param from the current assets owner.
 * @param to the address to send the assets to.
 * @param amount the amount to release.
 */
function _transferFrom(address assetContract, address from, address to, uint256 amount) {
    IERC20(assetContract).transferFrom(from, to, amount);
}

/**
 * Sets unlimited approval for the token to an operator.
 * @param assetContract the contract that controls the asset.
 * @param operator the account being granted approval.
 * @param approved flag indicating setting or removing approval.
 */
function _setApprovalForAll(address assetContract, address operator, bool approved) {
    uint256 amount = approved ? type(uint256).max : 0;
    IERC20(assetContract).approve(operator, amount);
}
