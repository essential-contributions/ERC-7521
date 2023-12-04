// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseUserOperation} from "../base/BaseUserOperation.sol";

contract EmbeddableUserOperation is BaseUserOperation {
    uint256 private constant _USER_OPERATION_STANDARD_ID = 1;
    bytes32 internal constant USER_OPERATION_STANDARD_ID = bytes32(_USER_OPERATION_STANDARD_ID);

    function getUserOperationStandardId() public pure returns (bytes32) {
        return USER_OPERATION_STANDARD_ID;
    }
}
