// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

/**
 * @notice The minimal "Wrapped Ether" ERC-20 token implementation.
 */
contract TestWrappedNativeToken is ERC20 {
    // solhint-disable-next-line no-empty-blocks
    constructor() ERC20("Wrapped Native Token", "wnTok") {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
