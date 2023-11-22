// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract Erc20ReleaseDelegate {
    /**
     * Basic state and constants.
     */
    address private immutable _this;

    /**
     * Contract constructor.
     */
    constructor() {
        _this = address(this);
    }

    /**
     * Release the given ERC-20 tokens
     * @dev only allowed to be called via a delegate call
     * @param erc20Contract the contract that controls the erc20.
     * @param to the target to release tokens to.
     * @param amount the amount to release.
     */
    function releaseErc20(address erc20Contract, address to, uint256 amount) external {
        require(address(this) != _this, "must be delegate call");
        IERC20(erc20Contract).transfer(to, amount);
    }

    function _encodeReleaseErc20(address erc20Contract, address to, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(this.releaseErc20.selector, erc20Contract, to, amount);
    }
}
