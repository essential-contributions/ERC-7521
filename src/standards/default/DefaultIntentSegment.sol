// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../interfaces/UserIntent.sol";

/**
 * Default Intent Segment struct
 * @param callGasLimit max gas to be spent on the intent call data.
 * @param callData the intents desired call data.
 */
struct DefaultIntentSegment {
    uint256 callGasLimit;
    bytes callData;
}

/**
 * Helper function to extract DefaultIntentSegment from a UserIntent.
 */
function parseDefaultIntentSegment(UserIntent calldata intent, uint256 index)
    pure
    returns (DefaultIntentSegment calldata segment)
{
    bytes calldata intentData = intent.intentData[index];
    assembly {
        segment := intentData.offset
    }
}
