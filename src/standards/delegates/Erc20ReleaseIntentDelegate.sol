// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Erc20Curve} from "../../utils/curves/Erc20Curve.sol";
import {_balanceOf, _transfer} from "../../utils/wrappers/Erc20Wrapper.sol";

contract Erc20ReleaseIntentDelegate {
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
        require(_balanceOf(erc20Contract, address(this)) >= amount, "insufficient release balance");
        _transfer(erc20Contract, to, amount);
    }

    function _encodeReleaseErc20(Erc20Curve calldata erc20Release, address to, uint256 amount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(this.releaseErc20.selector, erc20Release.erc20Contract, to, amount);
    }
}
