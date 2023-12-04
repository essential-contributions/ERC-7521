// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseEthRelease} from "../base/BaseEthRelease.sol";

contract EmbeddableEthRelease is BaseEthRelease {
    uint256 private constant _ETH_RELEASE_STANDARD_ID = 3;
    bytes32 internal constant ETH_RELEASE_STANDARD_ID = bytes32(_ETH_RELEASE_STANDARD_ID);

    function getEthReleaseStandardId() public pure returns (bytes32) {
        return ETH_RELEASE_STANDARD_ID;
    }
}
