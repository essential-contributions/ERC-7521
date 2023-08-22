// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EntryPointTruster} from "./EntryPointTruster.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";

/**
 * Foundational contract for any contract that expects communication from an entrypoint contract.
 */
abstract contract IntentStandardTruster is EntryPointTruster, IIntentDelegate {
    // keeps track of trusted intent standards
    mapping(bytes32 => IIntentStandard) internal _trustedIntentStandards;

    /**
     * trusts a new intent standard.
     */
    function addTrustedIntentStandard(IIntentStandard intentStandard) external virtual returns (bytes32);

    /**
     * ensure the entrypoint is currently in the intent execution stage for this sender.
     */
    modifier onlyFromIntentStandardExecutingForSender(IIntentStandard intentStandard) {
        require(
            address(_trustedIntentStandards[entryPoint().getIntentStandardId(intentStandard)]) != address(0),
            "not from trusted intent standard"
        );
        require(entryPoint().executingIntentSender() == address(this), "EntryPoint not executing intent");
        _;
    }
}
