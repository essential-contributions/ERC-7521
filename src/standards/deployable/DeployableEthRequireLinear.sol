// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseEthRequireLinear} from "../base/BaseEthRequireLinear.sol";
import {IDeployableIntentStandard} from "../../interfaces/IDeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableEthRequireLinear is BaseEthRequireLinear, IDeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseEthRequireLinear._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external view override returns (bytes memory) {
        return BaseEthRequireLinear._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
