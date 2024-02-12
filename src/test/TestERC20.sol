// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC20("TST20", "TestERC20")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev Super unsafe function to set approval for another account
     */
    function approveFor(address owner, address spender, uint256 amount) public returns (bool) {
        _approve(owner, spender, amount);
        return true;
    }
}
