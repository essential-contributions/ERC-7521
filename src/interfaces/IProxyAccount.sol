// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IProxyAccount {
    /**
     * Gets the EOA address this account is a proxy for.
     * @return address the EOA this account is a proxy for.
     */
    function proxyFor() external view returns (address);
}
