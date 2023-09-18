// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20, Test {
    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC20("TST20", "TestERC20")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function testNothing() public {}
}
