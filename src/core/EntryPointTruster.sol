// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {BaseIntentStandard} from "../interfaces/BaseIntentStandard.sol";

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
     * ensure
     * 1. entrypoint is currently executing an intent that was made by this contract.
     * 2. the caller intent standard is the one that the entrypoint is currently executing for.
     */
    modifier onlyFromIntentStandardExecutingForSender() {
        require(
            entryPoint().verifyExecutingIntentSegmentForStandard(BaseIntentStandard(msg.sender)),
            "EntryPoint not executing intent standard for sender"
        );
        _;
    }
}
