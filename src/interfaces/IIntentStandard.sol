// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "./UserIntent.sol";

interface IIntentStandard {
    /**
     * Validate intent structure (typically just formatting)
     * @param userInt the intent that is about to be solved.
     */
    function validateUserInt(UserIntent calldata userInt) external;

    function executeFirstPass(UserIntent calldata userInt, uint256 timestamp)
        external
        returns (bytes memory endContext);

    function executeSecondPass(UserIntent calldata userInt, uint256 timestamp, bytes memory context)
        external
        returns (bytes memory endContext);

    function verifyEndState(UserIntent calldata userInt, uint256 timestamp, bytes memory context) external;
}
