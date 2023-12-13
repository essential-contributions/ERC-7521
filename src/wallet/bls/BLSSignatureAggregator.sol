//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;
pragma abicoder v2;

import "../../interfaces/IAggregator.sol";
import "../../interfaces/IEntryPoint.sol";
import "../../interfaces/UserIntent.sol";
import {BLSOpen} from "./lib/BLSOpen.sol";
import "./IBLSAccount.sol";
import "./BLSHelper.sol";

/**
 * A BLS-based signature aggregator, to validate aggregated signature of multiple UserIntents if BLSAccount
 */
contract BLSSignatureAggregator is IAggregator {
    using UserIntentLib for UserIntent;

    bytes32 public constant BLS_DOMAIN = keccak256("eip4337.bls.domain");

    //copied from BLS.sol
    uint256 public constant N = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    address public immutable entryPoint;

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
    }

    /**
     * @return publicKey - the public key from a BLS keypair the Aggregator will use to verify this UserIntent;
     *         queried from the deployed BLSAccount;
     */
    function getUserIntentPublicKey(UserIntent memory userIntent) public view returns (uint256[4] memory publicKey) {
        return IBLSAccount(userIntent.sender).getBlsPublicKey{gas: 50000}();
    }

    /// @inheritdoc IAggregator
    function validateSignatures(UserIntent[] calldata userIntents, bytes calldata signature) external view override {
        require(signature.length == 64, "BLS: invalid signature");
        (uint256[2] memory blsSignature) = abi.decode(signature, (uint256[2]));

        uint256 userIntentsLen = userIntents.length;
        uint256[4][] memory blsPublicKeys = new uint256[4][](userIntentsLen);
        uint256[2][] memory messages = new uint256[2][](userIntentsLen);
        for (uint256 i = 0; i < userIntentsLen; i++) {
            UserIntent memory userIntent = userIntents[i];
            blsPublicKeys[i] = getUserIntentPublicKey(userIntent);

            messages[i] = _userIntentToMessage(userIntent, _getPublicKeyHash(blsPublicKeys[i]));
        }
        require(BLSOpen.verifyMultiple(blsSignature, blsPublicKeys, messages), "BLS: validateSignatures failed");
    }

    /**
     * get a hash of userIntent
     * NOTE: this hash is not the same as UserIntent.hash()
     *  (slightly less efficient, since it uses memory userIntent)
     */
    function internalUserIntentHash(UserIntent memory userIntent) internal pure returns (bytes32) {
        return keccak256(abi.encode(userIntent.sender, keccak256(abi.encode(userIntent.intentData))));
    }

    /**
     * return the BLS "message" for the given UserIntent.
     * the account checks the signature over this value using its public key
     */
    function userIntentToMessage(UserIntent memory userIntent) public view returns (uint256[2] memory) {
        bytes32 publicKeyHash = _getPublicKeyHash(getUserIntentPublicKey(userIntent));
        return _userIntentToMessage(userIntent, publicKeyHash);
    }

    function _userIntentToMessage(UserIntent memory userIntent, bytes32 publicKeyHash)
        internal
        view
        returns (uint256[2] memory)
    {
        bytes32 userIntentHash = _getUserIntentHash(userIntent, publicKeyHash);
        return BLSOpen.hashToPoint(BLS_DOMAIN, abi.encodePacked(userIntentHash));
    }

    function getUserIntentHash(UserIntent memory userIntent) public view returns (bytes32) {
        bytes32 publicKeyHash = _getPublicKeyHash(getUserIntentPublicKey(userIntent));
        return _getUserIntentHash(userIntent, publicKeyHash);
    }

    function _getUserIntentHash(UserIntent memory userIntent, bytes32 publicKeyHash) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                internalUserIntentHash(userIntent), publicKeyHash, address(this), block.chainid, address(entryPoint)
            )
        );
    }

    function _getPublicKeyHash(uint256[4] memory publicKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(publicKey));
    }
    /**
     * validate signature of a single userIntent
     * This method is called after EntryPoint.simulateValidation() returns an aggregator.
     * First it validates the signature over the userIntent. then it return data to be used when creating the handleIntents:
     * @param userIntent the UserIntent received from the user.
     * @return sigForUserIntent the value to put into the signature field of the userIntent when calling handleIntents.
     *    (usually empty, unless account and aggregator support some kind of "multisig"
     */

    function validateIntentSignature(UserIntent calldata userIntent)
        external
        view
        returns (bytes memory sigForUserIntent)
    {
        uint256[2] memory signature = abi.decode(userIntent.signature, (uint256[2]));
        uint256[4] memory pubkey = getUserIntentPublicKey(userIntent);
        uint256[2] memory message = _userIntentToMessage(userIntent, _getPublicKeyHash(pubkey));

        require(BLSOpen.verifySingle(signature, pubkey, message), "BLS: wrong sig");
        return "";
    }

    /**
     * aggregate multiple signatures into a single value.
     * This method is called off-chain to calculate the signature to pass with handleIntents()
     * bundler MAY use optimized custom code perform this aggregation
     * @param userIntents array of UserIntents to collect the signatures from.
     * @return aggregatedSignature the aggregated signature
     */
    function aggregateSignatures(UserIntent[] calldata userIntents)
        external
        pure
        returns (bytes memory aggregatedSignature)
    {
        BLSHelper.XY[] memory points = new BLSHelper.XY[](userIntents.length);
        for (uint256 i = 0; i < points.length; i++) {
            (uint256 x, uint256 y) = abi.decode(userIntents[i].signature, (uint256, uint256));
            points[i] = BLSHelper.XY(x, y);
        }
        BLSHelper.XY memory sum = BLSHelper.sum(points, N);
        return abi.encode(sum.x, sum.y);
    }
}
