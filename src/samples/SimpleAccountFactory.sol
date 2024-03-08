// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {SimpleAccount} from "./SimpleAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * A sample factory contract for SimpleAccount
 */
contract SimpleAccountFactory {
    SimpleAccount public immutable accountImplementation;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new SimpleAccount(_entryPoint);
    }

    /**
     * Create an account, and return its address.
     *
     * @param owner the account owner
     * @param salt for uniqueness
     */
    function createAccount(address owner, uint256 salt) public returns (SimpleAccount) {
        address addr = getAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(addr));
        }
        return SimpleAccount(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation), abi.encodeCall(SimpleAccount.initialize, (owner))
                )
            )
        );
    }

    /**
     * Calculate the counterfactual address of this account as it would be returned by createAccount().
     *
     * @param owner the account owner
     * @param salt for uniqueness
     */
    function getAddress(address owner, uint256 salt) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(address(accountImplementation), abi.encodeCall(SimpleAccount.initialize, (owner)))
                )
            )
        );
    }
}
