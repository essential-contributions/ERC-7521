// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseAccount} from "../core/BaseAccount.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {_packValidationData} from "../utils/Helpers.sol";
import {IAssetRelease} from "../standards/assetbased/IAssetRelease.sol";
import {_balanceOf, _transfer, AssetType} from "../standards/assetbased/utils/AssetWrapper.sol";
import {TokenCallbackHandler} from "./TokenCallbackHandler.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

contract AbstractAccount is BaseAccount, TokenCallbackHandler, IAssetRelease {
    using ECDSA for bytes32;

    address public owner;

    IEntryPoint private immutable _entryPoint;

    event AccountCreated(IEntryPoint indexed entryPoint, address indexed owner);
    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    constructor(IEntryPoint anEntryPoint, address _owner) {
        _entryPoint = anEntryPoint;
        owner = _owner;
        emit AccountCreated(anEntryPoint, _owner);
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address target, uint256 value, bytes calldata data) external onlyFromEntryPointIntentExecuting {
        _call(target, value, data);
        emit Executed(_entryPoint, target, value, data);
    }

    /**
     * Execute multiple transactions called from entry point while the entry point is in intent executing state.
     */
    function executeMulti(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas)
        external
        onlyFromEntryPointIntentExecuting
    {
        require(targets.length == values.length, "invalid multi call inputs");
        require(targets.length == datas.length, "invalid multi call inputs");

        for (uint256 i = 0; i < targets.length; i++) {
            _call(targets[i], values[i], datas[i]);
            emit Executed(_entryPoint, targets[i], values[i], datas[i]);
        }
    }

    /**
     * Releases asset(s) to the target recipient.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external
        override
        onlyFromEntryPointIntentExecuting
    {
        require(_balanceOf(assetType, assetContract, assetId, address(this)) >= amount, "insufficient release balance");
        _transfer(assetType, assetContract, assetId, address(this), to, amount);
    }

    /// implement template method of BaseAccount
    function _validateSignature(UserIntent calldata userInt, bytes32 userIntHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = userIntHash.toEthSignedMessageHash();
        if (owner != hash.recover(userInt.signature)) {
            return _packValidationData(true, uint48(userInt.timestamp), 0);
        }
        return _packValidationData(false, uint48(userInt.timestamp), 0);
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
