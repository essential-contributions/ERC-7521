// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseEthRequireExponential} from "../base/BaseEthRequireExponential.sol";
import {IDeployableIntentStandard} from "../../interfaces/IDeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableEthRequireExponential is BaseEthRequireExponential, IDeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseEthRequireExponential._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external view override returns (bytes memory) {
        return BaseEthRequireExponential._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
