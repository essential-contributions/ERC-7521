// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {IIntentStandardRegistry} from "../interfaces/IIntentStandardRegistry.sol";
import {IDeployableIntentStandard} from "../interfaces/IDeployableIntentStandard.sol";

abstract contract IntentStandardRegistry is IIntentStandardRegistry {
    //keeps track of registered intent standards
    mapping(bytes32 => IDeployableIntentStandard) internal _registeredStandards;

    /**
     * registers a new intent standard.
     */
    function registerIntentStandard(IDeployableIntentStandard intentStandard) external returns (bytes32) {
        bytes32 standardId = _generateIntentStandardId(intentStandard);
        require(address(_registeredStandards[standardId]) == address(0), "AA81 already registered");

        _registeredStandards[standardId] = intentStandard;
        return standardId;
    }

    /**
     * gets the intent standard contract for the given intent standard ID.
     */
    function getIntentStandardContract(bytes32 standardId) external view returns (IDeployableIntentStandard) {
        IDeployableIntentStandard intentStandard = _registeredStandards[standardId];
        require(intentStandard != IDeployableIntentStandard(address(0)), "AA82 unknown standard");
        return intentStandard;
    }

    /**
     * gets the intent standard ID for the given intent standard contract.
     */
    function getIntentStandardId(IDeployableIntentStandard intentStandard) external view returns (bytes32) {
        bytes32 standardId = _generateIntentStandardId(intentStandard);
        require(_registeredStandards[standardId] != IDeployableIntentStandard(address(0)), "AA82 unknown standard");
        return standardId;
    }

    /**
     * generates an intent standard ID for an intent standard contract.
     */
    function _generateIntentStandardId(IDeployableIntentStandard intentStandard) private view returns (bytes32) {
        return keccak256(abi.encodePacked(intentStandard, address(this), block.chainid));
    }
}
