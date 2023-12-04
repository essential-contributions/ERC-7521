// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseIntentStandard} from "./BaseIntentStandard.sol";
import {IEntryPoint} from "./IEntryPoint.sol";
import {IntentSolution} from "./IntentSolution.sol";
import {UserIntent} from "./UserIntent.sol";

abstract contract DeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure virtual;

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external virtual returns (bytes memory);
}
