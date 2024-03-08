// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

contract EthReleaseDelegate {
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
     * Release the given amount of ETH
     * @dev only allowed to be called via a delegate call
     * @param to the target to release ETH to.
     * @param amount the amount to release.
     */
    function releaseEth(address to, uint256 amount) external {
        require(address(this) != _this, "must be delegate call");
        payable(to).transfer(amount);
    }

    function _encodeReleaseEth(address to, uint256 amount) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(this.releaseEth.selector, to, amount);
    }
}
