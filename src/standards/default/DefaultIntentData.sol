// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../interfaces/UserIntent.sol";

/**
 * Default Intent Data struct
 * @param callGasLimit max gas to be spent on the intent call data.
 * @param callData the intents desired call data.
 */
struct DefaultIntentData {
    uint256 callGasLimit;
    bytes callData;
}

/**
 * Helper function to extract DefaultIntentData from a UserIntent.
 */
function parseDefaultIntentData(UserIntent calldata intent) pure returns (DefaultIntentData calldata data) {
    bytes calldata intentData = intent.intentData;
    assembly {
        data := intentData.offset
    }
}
