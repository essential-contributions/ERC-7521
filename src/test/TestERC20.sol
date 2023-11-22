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
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
