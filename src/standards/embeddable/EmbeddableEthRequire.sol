// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseEthRequire} from "../base/BaseEthRequire.sol";

contract EmbeddableEthRequire is BaseEthRequire {
    uint256 private constant _ETH_REQUIRE_STANDARD_ID = 4;
    bytes32 internal constant ETH_REQUIRE_STANDARD_ID = bytes32(_ETH_REQUIRE_STANDARD_ID);

    function getEthRequireStandardId() public pure returns (bytes32) {
        return ETH_REQUIRE_STANDARD_ID;
    }
}
