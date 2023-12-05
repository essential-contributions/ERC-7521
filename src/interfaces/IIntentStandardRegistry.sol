// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IDeployableIntentStandard} from "./IDeployableIntentStandard.sol";

interface IIntentStandardRegistry {
    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(IDeployableIntentStandard intentStandard) external returns (bytes32);

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IDeployableIntentStandard);

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(IDeployableIntentStandard intentStandard) external view returns (bytes32);
}
