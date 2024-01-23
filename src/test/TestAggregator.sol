// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";

bytes32 constant ADMIN_SIGNATURE = keccak256("TestAggregator");

/**
 * A test signature aggregator
 */
contract TestAggregator is IAggregator {
    /// @inheritdoc IAggregator
    function validateSignatures(UserIntent[] calldata, bytes calldata signature) external pure override {
        (bytes32 sig) = abi.decode(signature, (bytes32));
        require(sig == ADMIN_SIGNATURE, "Invalid aggregate signature");
    }

    /// @inheritdoc IAggregator
    function validateIntentSignature(UserIntent calldata) external pure override returns (bytes memory sigForUserOp) {
        //everything is valid
        return "";
    }

    /// @inheritdoc IAggregator
    function aggregateSignatures(UserIntent[] calldata) external pure returns (bytes memory) {
        return abi.encode(ADMIN_SIGNATURE);
    }
}
