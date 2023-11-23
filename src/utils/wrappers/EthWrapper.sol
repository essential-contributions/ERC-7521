// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

/**
 * Gets the balance of ETH.
 * @param owner the owner to check the balance of.
 */
function _balanceOf(address owner) view returns (uint256) {
    return owner.balance;
}

/**
 * Transfers ETH.
 * @param to the address to send the assets to.
 * @param amount the amount to release.
 */
function _transfer(address to, uint256 amount) {
    payable(to).transfer(amount);
}
