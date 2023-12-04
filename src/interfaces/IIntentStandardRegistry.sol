// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {DeployableIntentStandard} from "./DeployableIntentStandard.sol";

interface IIntentStandardRegistry {
    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(DeployableIntentStandard intentStandard) external returns (bytes32);

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (DeployableIntentStandard);

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(DeployableIntentStandard intentStandard) external view returns (bytes32);
}
