// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EthReleaseIntentCurve} from "./EthReleaseIntentCurve.sol";

/**
 * Eth Release Intent Segment struct
 * @param release release curve.
 */
struct EthReleaseIntentSegment {
    EthReleaseIntentCurve release;
}
