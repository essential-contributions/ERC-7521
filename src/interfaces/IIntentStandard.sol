// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {UserIntent} from "./UserIntent.sol";

interface IIntentStandard {
    function executeCallData1(UserIntent calldata userInt) external;

    function executeCallData2(UserIntent calldata userInt) external;

    function verifyEndState(UserIntent calldata userInt) external;

    function hash(UserIntent calldata userInt) external pure returns (bytes32);
}
