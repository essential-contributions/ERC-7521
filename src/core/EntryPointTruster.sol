// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";

/**
 * Foundational contract for any contract that expects communication from an entrypoint contract.
 */
abstract contract EntryPointTruster {
    /**
     * return the entryPoint used by this contract.
     * subclass should return the current entryPoint used by this account.
     */
    function entryPoint() public view virtual returns (IEntryPoint);

    /**
     * ensure the intent comes from the known entrypoint.
     */
    modifier onlyFromEntryPoint() {
        require(msg.sender == address(entryPoint()), "not from EntryPoint");
        _;
    }

    /**
     * ensure the entrypoint is currently in the intent execution stage for this sender
     * and that the intent standard is registered.
     */
    modifier onlyFromIntentStandardExecutingForSender(IIntentStandard intentStandard) {
        require(
            address(entryPoint().getIntentStandardContract(entryPoint().getIntentStandardId(intentStandard)))
                != address(0),
            "not from a registered intent standard"
        );
        require(entryPoint().executingIntentSender() == address(this), "EntryPoint not executing intent");
        _;
    }
}
