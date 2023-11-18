// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {EthCurve} from "../../utils/curves/EthCurve.sol";
import {_balanceOf, _transfer} from "../../utils/wrappers/EthWrapper.sol";

contract EthReleaseIntentDelegate {
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
     * Release the given token(s) (both fungible and non-fungible)
     * @dev only allowed to be called via a delegate call
     * @param to the target to release tokens to.
     * @param amount the amount to release.
     */
    function releaseEth(address to, uint256 amount) external {
        require(address(this) != _this, "must be delegate call");
        require(_balanceOf(address(this)) >= amount, "insufficient release balance");
        _transfer(to, amount);
    }

    function _encodeReleaseEth(address to, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(this.releaseEth.selector, to, amount);
    }
}
