// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseEthReleaseExponential} from "../base/BaseEthReleaseExponential.sol";
import {IDeployableIntentStandard} from "../../interfaces/IDeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableEthReleaseExponential is BaseEthReleaseExponential, IDeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseEthReleaseExponential._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseEthReleaseExponential._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
