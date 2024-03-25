// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {IntentSolution, IntentSolutionLib} from "../../interfaces/IntentSolution.sol";
import {IBLSSignatureAggregator} from "./IBLSSignatureAggregator.sol";
import {IBLSAccount} from "./IBLSAccount.sol";
import {EllipticCurve} from "./lib/EllipticCurve.sol";
import {BLS} from "./lib/BLS.sol";

/**
 * A BLS-based signature aggregator, to validate aggregated signature of multiple UserOps if BLSAccount
 */
contract BLSSignatureAggregator is IBLSSignatureAggregator {
    using UserIntentLib for UserIntent;

    bytes32 public constant BLS_DOMAIN = keccak256("erc7521.bls.domain");

    IEntryPoint private immutable _entryPoint;

    constructor(IEntryPoint entryPoint) {
        _entryPoint = entryPoint;
    }

    /// @inheritdoc IBLSSignatureAggregator
    function handleIntentsAggregated(
        IntentSolution[] calldata solutions,
        bytes32 intentsToAggregate,
        bytes calldata signature
    ) external {
        // get number of intents
        uint256 solsLen = solutions.length;
        uint256 totalIntents = 0;
        unchecked {
            for (uint256 i = 0; i < solsLen; i++) {
                totalIntents += solutions[0].intents.length;
            }
        }
        uint256 aggregatedIntentTotal = 0;
        for (uint256 i = 0; i < totalIntents; i++) {
            if ((uint256(intentsToAggregate) & (1 << i)) > 0) aggregatedIntentTotal++;
        }

        // validate aggregated intent signature
        uint256[4][] memory blsPublicKeys = new uint256[4][](aggregatedIntentTotal);
        uint256[2][] memory messages = new uint256[2][](aggregatedIntentTotal);
        uint256 k = 0;
        uint256 l = 0;
        for (uint256 i = 0; i < solsLen; i++) {
            for (uint256 j = 0; j < solutions[i].intents.length; j++) {
                if ((uint256(intentsToAggregate) & (1 << k)) > 0) {
                    UserIntent calldata intent = solutions[i].intents[j];
                    bytes32 intentHash = _intentHash(intent);
                    blsPublicKeys[l] = _getIntentPublicKey(intent);
                    messages[l] = _intentMessage(intentHash);
                    l++;

                    // remember validated intents
                    assembly {
                        tstore(intentHash, 1)
                    }
                }
                k++;
            }
        }
        _validateSignatures(blsPublicKeys, messages, signature);

        // call handle intents on the entrypoint
        _entryPoint.handleIntentsMulti(solutions);
    }

    /// @inheritdoc IBLSSignatureAggregator
    function isValidated(bytes32 intentHash) external view returns (bool) {
        bool validated;
        assembly {
            validated := tload(intentHash)
        }
        return validated;
    }

    /// @inheritdoc IBLSSignatureAggregator
    function validateSignature(UserIntent calldata intent) external view {
        uint256[2] memory signature = abi.decode(intent.signature, (uint256[2]));
        uint256[4] memory pubkey = _getIntentPublicKey(intent);
        uint256[2] memory message = _intentMessage(_intentHash(intent));

        BLS.verifySingle(signature, pubkey, message);
    }

    /// @inheritdoc IBLSSignatureAggregator
    function validateSignatures(UserIntent[] calldata intents, bytes calldata signature) public view override {
        uint256 intentsLen = intents.length;
        uint256[4][] memory blsPublicKeys = new uint256[4][](intentsLen);
        uint256[2][] memory messages = new uint256[2][](intentsLen);
        for (uint256 i = 0; i < intentsLen; i++) {
            UserIntent calldata intent = intents[i];
            blsPublicKeys[i] = _getIntentPublicKey(intent);
            messages[i] = _intentMessage(_intentHash(intent));
        }
        _validateSignatures(blsPublicKeys, messages, signature);
    }

    /// @inheritdoc IBLSSignatureAggregator
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

    function _validateSignatures(
        uint256[4][] memory blsPublicKeys,
        uint256[2][] memory messages,
        bytes calldata signature
    ) internal view {
        require(signature.length == 64, "invalid bls aggregated signature");
        (uint256[2] memory blsSignature) = abi.decode(signature, (uint256[2]));

        BLS.verifyMultiple(blsSignature, blsPublicKeys, messages);
    }

    function _getIntentPublicKey(UserIntent calldata intent) internal view returns (uint256[4] memory publicKey) {
        return IBLSAccount(intent.sender).getBlsPublicKey{gas: 50000}();
    }

    function _intentHash(UserIntent calldata intent) internal view returns (bytes32) {
        return keccak256(abi.encode(intent.hash(), address(_entryPoint), block.chainid));
    }

    function _intentMessage(bytes32 intentHash) internal view returns (uint256[2] memory) {
        return BLS.hashToPoint(BLS_DOMAIN, abi.encodePacked(intentHash));
    }
}
