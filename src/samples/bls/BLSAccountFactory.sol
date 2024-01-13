// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BLSAccount} from "./BLSAccount.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {IAggregator} from "../../interfaces/IAggregator.sol";
import {Create2} from "openzeppelin/utils/Create2.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * A sample factory contract for BLSAccount
 */
contract BLSAccountFactory {
    BLSAccount public immutable accountImplementation;

    constructor(IEntryPoint _entryPoint, IAggregator _aggregator) {
        accountImplementation = new BLSAccount(_entryPoint, _aggregator);
    }

    /**
     * Create an account, and return its address.
     *
     * @param publicKey the account public key for aggregation
     * @param owner the account owner
     * @param salt for uniqueness
     */
    function createAccount(uint256[4] calldata publicKey, address owner, uint256 salt) public returns (BLSAccount) {
        address addr = getAddress(publicKey, owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return BLSAccount(payable(addr));
        }
        return BLSAccount(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation), abi.encodeCall(BLSAccount.initialize, (publicKey, owner))
                )
            )
        );
    }

    /**
     * Calculate the counterfactual address of this account as it would be returned by createAccount().
     *
     * @param publicKey the account public key for aggregation
     * @param owner the account owner
     * @param salt for uniqueness
     */
    function getAddress(uint256[4] calldata publicKey, address owner, uint256 salt) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(accountImplementation), abi.encodeCall(BLSAccount.initialize, (publicKey, owner))
                    )
                )
            )
        );
    }

    /**
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test_test() public {}
}
