// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IAggregator} from "../../interfaces/IAggregator.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {IBLSAccount} from "./IBLSAccount.sol";
import {EllipticCurve} from "./lib/EllipticCurve.sol";
import {BLS} from "./lib/BLS.sol";

/**
 * A BLS-based signature aggregator, to validate aggregated signature of multiple UserOps if BLSAccount
 */
contract BLSSignatureAggregator is IAggregator {
    using UserIntentLib for UserIntent;

    bytes32 public constant BLS_DOMAIN = keccak256("erc7521.bls.domain");

    IEntryPoint private immutable _entryPoint;

    constructor(IEntryPoint entryPoint) {
        _entryPoint = entryPoint;
    }

    /// @inheritdoc IAggregator
    function validateSignatures(UserIntent[] calldata intents, bytes calldata signature) external view override {
        require(signature.length == 64, "invalid bls aggregated signature");
        (uint256[2] memory blsSignature) = abi.decode(signature, (uint256[2]));

        uint256 intentsLen = intents.length;
        uint256[4][] memory blsPublicKeys = new uint256[4][](intentsLen);
        uint256[2][] memory messages = new uint256[2][](intentsLen);
        for (uint256 i = 0; i < intentsLen; i++) {
            UserIntent calldata intent = intents[i];
            blsPublicKeys[i] = _getIntentPublicKey(intent);

            messages[i] = _intentMessage(intent);
        }
        BLS.verifyMultiple(blsSignature, blsPublicKeys, messages);
    }

    /// @inheritdoc IAggregator
    function validateIntentSignature(UserIntent calldata intent) external view returns (bytes memory sigForUserOp) {
        uint256[2] memory signature = abi.decode(intent.signature, (uint256[2]));
        uint256[4] memory pubkey = _getIntentPublicKey(intent);
        uint256[2] memory message = _intentMessage(intent);

        BLS.verifySingle(signature, pubkey, message);
        return "";
    }

    /// @inheritdoc IAggregator
    function aggregateSignatures(UserIntent[] calldata intents)
        external
        pure
        returns (bytes memory aggregatedSignature)
    {
        uint256[2][] memory points = new uint256[2][](intents.length);
        for (uint256 i = 0; i < points.length; i++) {
            points[i] = abi.decode(intents[i].signature, (uint256[2]));
        }
        uint256[2] memory sum = EllipticCurve.sum(points, BLS.N);
        return abi.encode(sum[0], sum[1]);
    }

    function _getIntentPublicKey(UserIntent calldata intent) internal view returns (uint256[4] memory publicKey) {
        return IBLSAccount(intent.sender).getBlsPublicKey{gas: 50000}();
    }

    function _intentMessage(UserIntent calldata intent) internal view returns (uint256[2] memory) {
        //hash is equivalent to _entryPoint.getUserIntentHash(intent), but copied directly for gas savings
        bytes32 intentHash = keccak256(abi.encode(intent.hash(), address(_entryPoint), block.chainid));
        return BLS.hashToPoint(BLS_DOMAIN, abi.encodePacked(intentHash));
    }
}
