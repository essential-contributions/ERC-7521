// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseErc20ReleaseExponential} from "../base/BaseErc20ReleaseExponential.sol";
import {DeployableIntentStandard} from "../../interfaces/DeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableErc20ReleaseExponential is BaseErc20ReleaseExponential, DeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseErc20ReleaseExponential._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseErc20ReleaseExponential._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
