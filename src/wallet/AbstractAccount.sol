// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseAccount} from "../core/BaseAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {_packValidationData} from "../utils/Helpers.sol";
import {IAssetRelease} from "../standards/assetbased/IAssetRelease.sol";
import {_balanceOf, _transfer, AssetType} from "../standards/assetbased/utils/AssetWrapper.sol";
import {TokenCallbackHandler} from "./TokenCallbackHandler.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract AbstractAccount is BaseAccount, TokenCallbackHandler, IAssetRelease {
    using ECDSA for bytes32;

    address public owner;

    address private immutable _entryPoint;
    address private immutable _assetBasedIntentStandard;

    event AccountCreated(
        IEntryPoint indexed entryPoint, IIntentStandard indexed assetBasedIntentStandard, address indexed owner
    );
    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return IEntryPoint(_entryPoint);
    }

    constructor(IEntryPoint entryPointAddr, IIntentStandard assetBasedIntentStandardAddr, address _owner) {
        _entryPoint = address(entryPointAddr);
        _assetBasedIntentStandard = address(assetBasedIntentStandardAddr);
        owner = _owner;
        emit AccountCreated(entryPointAddr, assetBasedIntentStandardAddr, _owner);
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address target, uint256 value, bytes calldata data)
        external
        onlyFromIntentStandardExecutingForSender(_assetBasedIntentStandard)
    {
        _call(target, value, data);
        emit Executed(IEntryPoint(_entryPoint), target, value, data);
    }

    /**
     * Execute multiple transactions called from entry point while the entry point is in intent executing state.
     */
    function executeMulti(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        onlyFromIntentStandardExecutingForSender(_assetBasedIntentStandard)
    {
        // TODO: https://github.com/essential-contributions/galactus/issues/50
        require(targets.length == values.length, "____invalid multi call inputs___");
        require(targets.length == datas.length, "____invalid multi call inputs___");

        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
            emit Executed(IEntryPoint(_entryPoint), targets[i], values[i], datas[i]);
        }
    }

    /**
     * Releases asset(s) to the target recipient.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external
        override
        onlyFromIntentStandardExecutingForSender(_assetBasedIntentStandard)
    {
        // TODO: https://github.com/essential-contributions/galactus/issues/50
        require(
            _balanceOf(assetType, assetContract, assetId, address(this)) >= amount, "__insufficient release balance__"
        );
        _transfer(assetType, assetContract, assetId, address(this), to, amount);
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
