// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseErc20Record} from "../base/BaseErc20Record.sol";
import {DeployableIntentStandard} from "../../interfaces/DeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableErc20Record is BaseErc20Record, DeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseErc20Record._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external view override returns (bytes memory) {
        return BaseErc20Record._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
