// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "../../interfaces/UserIntent.sol";

/**
 * Operation Intent Segment struct
 * @param callGasLimit max gas to be spent on the intent call data.
 * @param callData the intents desired call data.
 */
struct OperationIntentSegment {
    uint256 callGasLimit;
    bytes callData;
}

/**
 * Helper function to extract OperationIntentSegment from a UserIntent.
 */
function parseOperationIntentSegment(UserIntent calldata intent, uint256 index)
    pure
    returns (OperationIntentSegment calldata segment)
{
    bytes calldata intentData = intent.intentData[index];
    assembly {
        segment := intentData.offset
    }
}
