// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/Create2.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import "./Account.sol";

/**
 * A sample factory for Wallet
 */
contract AccountFactory {
    Account public immutable accountImplementation;

    event AccountCreated(address indexed addr, address indexed owner);

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new Account(_entryPoint);
    }

    /**
     * Creates a wallet for an owner account at a specific address.
     * The wallet is created using Create2.
     * Returns the target account address either before or after the account is created.
     */
    function createAccount(address owner, uint256 salt) external returns (Account _account) {
        address addr = counterfactualAddress(owner, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            Account account = Account(payable(addr));
            emit AccountCreated(addr, owner);
            return account;
        }
        _account = Account(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation),
                    abi.encodeCall(Account.initialize, (owner))
                )
            )
        );
    }

    /**
     * Returns the counterfactual address of the account with given owner and salt.
     */
    function counterfactualAddress(address owner, uint256 salt) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(address(accountImplementation), abi.encodeCall(Account.initialize, (owner)))
                )
            )
        );
    }
}
