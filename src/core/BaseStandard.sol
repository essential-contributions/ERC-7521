// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import "forge-std/Test.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {EntryPointTruster} from "../core/EntryPointTruster.sol";

abstract contract BaseStandard is EntryPointTruster {
    /**
     * Basic state and constants.
     */
    IEntryPoint internal immutable _entryPoint;

    /**
     * Contract constructor.
     * @param entryPointContract the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPointContract) {
        _entryPoint = entryPointContract;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    function standardId() public view virtual returns (bytes32);
}
