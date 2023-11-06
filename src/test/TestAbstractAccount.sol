// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {AbstractAccount} from "../wallet/AbstractAccount.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * @notice Abstract account implementation that sets a non-zero `validAfter` value for intents.
 */
contract TestAbstractAccount is AbstractAccount, Test {
    using ECDSA for bytes32;

    constructor(IEntryPoint entryPointAddr, address _owner) AbstractAccount(entryPointAddr, _owner) {}

    function _validateSignature(UserIntent calldata intent, bytes32 intentHash)
        internal
        view
        virtual
        override
        returns (uint256 result)
    {
        bytes32 hash = intentHash.toEthSignedMessageHash();
        if (owner != hash.recover(intent.signature)) {
            return 1;
        }
        return 0; //sig failed
    }

    function testNothing() public {}
}
