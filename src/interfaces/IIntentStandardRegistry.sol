// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IIntentStandard} from "./IIntentStandard.sol";

interface IIntentStandardRegistry {
    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(IIntentStandard intentStandard) external returns (bytes32);

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IIntentStandard);

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(IIntentStandard intentStandard) external view returns (bytes32);
}
