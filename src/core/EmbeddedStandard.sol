// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/* solhint-disable private-vars-leading-underscore */

abstract contract EmbeddedStandard {
    function standardId() public view virtual returns (bytes32);
}
