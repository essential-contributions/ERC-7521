// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseSequentialNonce} from "../base/BaseSequentialNonce.sol";
import {IDeployableIntentStandard} from "../../interfaces/IDeployableIntentStandard.sol";
import {IntentSolution} from "../../interfaces/IntentSolution.sol";

contract DeployableSequentialNonce is BaseSequentialNonce, IDeployableIntentStandard {
    function validateIntentSegment(bytes calldata segmentData) external pure override {
        BaseSequentialNonce._validateIntentSegment(segmentData);
    }

    function executeIntentSegment(
        IntentSolution calldata solution,
        uint256 executionIndex,
        uint256 segmentIndex,
        bytes calldata context
    ) external override returns (bytes memory) {
        return BaseSequentialNonce._executeIntentSegment(solution, executionIndex, segmentIndex, context);
    }
}
