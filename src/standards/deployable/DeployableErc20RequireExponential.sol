// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseErc20RequireExponential} from "../base/BaseErc20RequireExponential.sol";
import {DeployableIntentStandard} from "../../interfaces/DeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableErc20RequireExponential is BaseErc20RequireExponential, DeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseErc20RequireExponential._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external view override returns (bytes memory) {
        return BaseErc20RequireExponential._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
