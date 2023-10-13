// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EthRequireIntentCurve} from "./EthRequireIntentCurve.sol";

/**
 * Eth Require Intent Segment struct
 * @param requirement asset that is required to be owned by the account at the end of the solution execution.
 */
struct EthRequireIntentSegment {
    EthRequireIntentCurve requirement;
}
