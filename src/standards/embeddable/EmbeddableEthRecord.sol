// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable private-vars-leading-underscore */

import {BaseEthRecord} from "../base/BaseEthRecord.sol";

contract EmbeddableEthRecord is BaseEthRecord {
    uint256 private constant _ETH_RECORD_STANDARD_ID = 2;
    bytes32 internal constant ETH_RECORD_STANDARD_ID = bytes32(_ETH_RECORD_STANDARD_ID);

    function getEthRecordStandardId() public pure returns (bytes32) {
        return ETH_RECORD_STANDARD_ID;
    }
}
