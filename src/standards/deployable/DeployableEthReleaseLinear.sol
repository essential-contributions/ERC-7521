// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseEthReleaseLinear} from "../base/BaseEthReleaseLinear.sol";
import {IDeployableIntentStandard} from "../../interfaces/IDeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableEthReleaseLinear is BaseEthReleaseLinear, IDeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseEthReleaseLinear._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseEthReleaseLinear._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
