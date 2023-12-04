// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseSimpleCall} from "../base/BaseSimpleCall.sol";

contract EmbeddableSimpleCall is BaseSimpleCall {
    bytes32 internal constant SIMPLE_CALL_STANDARD_ID = 0;

    function getSimpleCallStandardId() public pure returns (bytes32) {
        return SIMPLE_CALL_STANDARD_ID;
    }
}
