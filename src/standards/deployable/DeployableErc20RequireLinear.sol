// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseErc20RequireLinear} from "../base/BaseErc20RequireLinear.sol";
import {DeployableIntentStandard} from "../../interfaces/DeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableErc20RequireLinear is BaseErc20RequireLinear, DeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseErc20RequireLinear._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external view override returns (bytes memory) {
        return BaseErc20RequireLinear._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
