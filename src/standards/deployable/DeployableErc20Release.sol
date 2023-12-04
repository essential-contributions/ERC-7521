// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseErc20Release} from "../base/BaseErc20Release.sol";
import {DeployableIntentStandard} from "../../interfaces/DeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableErc20Release is BaseErc20Release, DeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseErc20Release._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseErc20Release._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
