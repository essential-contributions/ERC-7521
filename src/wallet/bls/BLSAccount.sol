// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.12;

import "./IBLSAccount.sol";
import "../../core/EntryPointTruster.sol";
import "../../interfaces/IAggregator.sol";
import "../../interfaces/IIntentDelegate.sol";
import {Exec} from "../../utils/Exec.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

/**
 * Minimal BLS-based account that uses an aggregated signature.
 * The account must maintain its own BLS public key, and expose its trusted signature aggregator.
 * Note that unlike the "standard" ECDSAAccount, this account can't be called directly
 * (normal ECDSAAccount uses its "signer" address as both the ecrecover signer, and as a legitimate
 * Ethereum sender address. Obviously, a BLS public key is not a valid Ethereum sender address.)
 */
contract BLSAccount is EntryPointTruster, IBLSAccount {
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    address public immutable aggregator;
    uint256[4] private publicKey;

    address private immutable _entryPoint;

    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }

    constructor(IEntryPoint entryPointAddr, address anAggregator, uint256[4] memory aPublicKey) {
        _entryPoint = address(entryPointAddr);
        aggregator = anAggregator;
        _setBlsPublicKey(aPublicKey);
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyFromIntentStandardExecutingForSender
    {
        _call(target, value, data);
        emit Executed(IEntryPoint(_entryPoint), target, value, data);
    }

    /**
     * Execute multiple transactions called from entry point while the entry point is in intent executing state.
     */
    function executeMulti(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        onlyFromIntentStandardExecutingForSender
    {
        require(targets.length == values.length, "invalid multi call inputs");
        require(targets.length == datas.length, "invalid multi call inputs");

        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
            emit Executed(IEntryPoint(_entryPoint), targets[i], values[i], datas[i]);
        }
    }

    /**
     * Make a call delegated through an intent standard.
     *
     * @param data calldata.
     * @return bool delegate call result.
     */
    function generalizedIntentDelegateCall(bytes memory data)
        external
        override
        onlyFromIntentStandardExecutingForSender
        returns (bool)
    {
        bool success = Exec.delegateCall(address(BaseIntentStandard(msg.sender)), data, gasleft());
        if (!success) {
            bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
            revert(string(reason));
        }
        return success;
    }
    /**
     * Validate user's intent (typically a signature)
     * the entryPoint will continue to execute an intent solution only if this validation call returns successfully.
     * @dev returning 0 indicates signature validated successfully.
     *
     * @param intent validate the intent.signature field
     * @return aggregator (optional) trusted signature aggregator to return if signature fails
     */

    function validateUserIntent(UserIntent calldata intent, bytes32)
        external
        view
        override(IAccount)
        returns (IAggregator)
    {
        IAggregator(aggregator).validateIntentSignature(intent);
        return IAggregator(aggregator);
    }

    /**
     * Allows the owner to set or change the BLS key.
     * @param newPublicKey public key from a BLS keypair that will have a full ownership and control of this account.
     */
    function setBlsPublicKey(uint256[4] memory newPublicKey) public {
        _setBlsPublicKey(newPublicKey);
    }

    function _setBlsPublicKey(uint256[4] memory newPublicKey) internal {
        emit PublicKeyChanged(publicKey, newPublicKey);
        publicKey = newPublicKey;
    }

    /// @inheritdoc IBLSAccount
    function getBlsPublicKey() public view override returns (uint256[4] memory) {
        return publicKey;
    }

    /**
     * Call and handle result.
     */
    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
