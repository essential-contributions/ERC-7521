// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IEntryPoint} from "../interfaces/IEntryPoint.sol";

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
     * ensure the entrypoint is currently in the validation stage.
     */
    modifier onlyFromEntryPointValidationExecuting() {
        require(msg.sender == address(entryPoint()), "not from EntryPoint");
        require(entryPoint().validationExecuting(), "EntryPoint not validating");
        _;
    }

    /**
     * ensure the entrypoint is currently in the validation stage.
     */
    modifier onlyFromEntryPointIntentExecuting() {
        require(msg.sender == address(entryPoint()), "not from EntryPoint");
        require(entryPoint().intentExecuting(), "EntryPoint not executing intents");
        _;
    }
}
