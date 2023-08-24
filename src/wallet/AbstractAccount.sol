// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {BaseAccount} from "../core/BaseAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";
import {_packValidationData} from "../utils/Helpers.sol";
import {_balanceOf, _transfer, AssetType} from "../standards/assetbased/utils/AssetWrapper.sol";
import {TokenCallbackHandler} from "./TokenCallbackHandler.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract AbstractAccount is BaseAccount, TokenCallbackHandler, IIntentDelegate {
    using ECDSA for bytes32;
    using RevertReason for bytes;

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    address public owner;

    address private immutable _entryPoint;

    event AccountCreated(IEntryPoint indexed entryPoint, address indexed owner);
    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }

    constructor(IEntryPoint entryPointAddr, address _owner) {
        _entryPoint = address(entryPointAddr);
        owner = _owner;
        (bytes32 defaultIntentStandardId, IIntentStandard defaultIntentStandard) =
            IEntryPoint(entryPointAddr).getDefaultIntentStandard();
        _trustedIntentStandards[defaultIntentStandardId] = defaultIntentStandard;
        emit AccountCreated(entryPointAddr, _owner);
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyFromIntentStandardExecutingForSender(IIntentStandard(msg.sender))
    {
        _call(target, value, data);
        emit Executed(IEntryPoint(_entryPoint), target, value, data);
    }

    /**
     * Execute multiple transactions called from entry point while the entry point is in intent executing state.
     */
    function executeMulti(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        onlyFromIntentStandardExecutingForSender(IIntentStandard(msg.sender))
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
        onlyFromIntentStandardExecutingForSender(IIntentStandard(msg.sender))
        returns (bool)
    {
        bool success = Exec.delegateCall(address(IIntentStandard(msg.sender)), data, gasleft());
        if (!success) {
            bytes memory reason = Exec.getRevertReasonMax(REVERT_REASON_MAX_LEN);
            revert(string(reason));
        }
        return success;
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserIntent calldata intent, bytes32 intentHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = intentHash.toEthSignedMessageHash();
        if (owner != hash.recover(intent.signature)) {
            return _packValidationData(true, uint48(intent.timestamp), 0);
        }
        return _packValidationData(false, uint48(intent.timestamp), 0);
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

    receive() external payable {}
}
