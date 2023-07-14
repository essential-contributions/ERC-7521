// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC20("TST20", "TestERC20")
    {}

    function mint(address sender, uint256 amount) external {
        _mint(sender, amount);
    }
}
