// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "../src/interfaces/UserIntent.sol";
import "../src/standards/assetbased/AssetBasedIntentStandard.sol";
import "../src/standards/assetbased/AssetBasedIntentData.sol";
import "../src/standards/assetbased/AssetBasedIntentCurve.sol";

/**
 * @title AssetBasedIntentBuilder
 * Utility functions helpful for building an asset based intent.
 */
library AssetBasedIntentBuilder {
    /**
     * Create a new user intent with the specified parameters.
     * @param standard The standard ID for the intent.
     * @param sender The address of the intent sender.
     * @param nonce The nonce to prevent replay attacks.
     * @param timestamp The unix time stamp (in seconds) from when this intent was signed.
     * @param callData1 The data for the first call.
     * @param callData2 The data for the second call.
     * @return userIntent The created user intent.
     */
    function create(
        bytes32 standard,
        address sender,
        uint256 nonce,
        uint256 timestamp,
        bytes memory callData1,
        bytes memory callData2
    ) public pure returns (UserIntent memory userIntent) {
        AssetBasedIntentCurve[] memory assetReleaseCurves;
        AssetBasedIntentCurve[] memory assetConstraintCurves;

        AssetBasedIntentData memory assetBasedIntentData = AssetBasedIntentData({
            callGasLimit1: 1000000,
            callGasLimit2: 1000000,
            callData1: callData1,
            callData2: callData2,
            assetReleases: assetReleaseCurves,
            assetConstraints: assetConstraintCurves
        });

        userIntent = UserIntent({
            standard: standard,
            sender: sender,
            nonce: nonce,
            timestamp: timestamp,
            verificationGasLimit: 1000000,
            intentData: "",
            signature: ""
        });
        userIntent = encodeData(userIntent, assetBasedIntentData);
    }

    /**
     * Add an asset release for ETH to the user intent.
     * @param intent The user intent to modify.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent.
     */
    function addReleaseETH(UserIntent memory intent, int256[] memory curve) public pure returns (UserIntent memory) {
        return _addAssetReleaseCurve(intent, address(0), uint256(0), AssetType.ETH, curve);
    }

    /**
     * Add an asset release for ERC20 tokens to the user intent.
     * @param intent The user intent to modify.
     * @param addr The address of the ERC20 token contract.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent.
     */
    function addReleaseERC20(UserIntent memory intent, address addr, int256[] memory curve)
        public
        pure
        returns (UserIntent memory)
    {
        return _addAssetReleaseCurve(intent, addr, uint256(0), AssetType.ERC20, curve);
    }

    /**
     * Add an asset release for ERC721 tokens to the user intent.
     * @param intent The user intent to modify.
     * @param addr The address of the ERC721 token contract.
     * @param id The ID of the ERC721 token.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent.
     */
    function addReleaseERC721(UserIntent memory intent, address addr, uint256 id, int256[] memory curve)
        public
        pure
        returns (UserIntent memory)
    {
        return _addAssetReleaseCurve(intent, addr, id, AssetType.ERC721, curve);
    }

    /**
     * Add an asset release for ERC1155 tokens to the user intent.
     * @param intent The user intent to modify.
     * @param addr The address of the ERC1155 token contract.
     * @param id The ID of the ERC1155 token.
     * @param curve The curve parameters for the asset release.
     * @return The updated user intent.
     */
    function addReleaseERC1155(UserIntent memory intent, address addr, uint256 id, int256[] memory curve)
        public
        pure
        returns (UserIntent memory)
    {
        return _addAssetReleaseCurve(intent, addr, id, AssetType.ERC1155, curve);
    }

    /**
     * Add an end state required asset of ETH to the user intent.
     * @param intent The user intent to modify.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent.
     */
    function addRequiredETH(UserIntent memory intent, int256[] memory curve, bool relative)
        public
        pure
        returns (UserIntent memory)
    {
        return _addAssetReqCurve(intent, address(0), uint256(0), AssetType.ETH, curve, relative);
    }

    /**
     * Add an end state required asset of ERC20 tokens to the user intent.
     * @param intent The user intent to modify.
     * @param addr The address of the ERC20 token contract.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent.
     */
    function addRequiredERC20(UserIntent memory intent, address addr, int256[] memory curve, bool relative)
        public
        pure
        returns (UserIntent memory)
    {
        return _addAssetReqCurve(intent, addr, uint256(0), AssetType.ERC20, curve, relative);
    }

    /**
     * Add an end state required asset of ERC721 tokens to the user intent.
     * @param intent The user intent to modify.
     * @param addr The address of the ERC721 token contract.
     * @param id The ID of the ERC721 token.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent.
     */
    function addRequiredERC721(UserIntent memory intent, address addr, uint256 id, int256[] memory curve, bool relative)
        public
        pure
        returns (UserIntent memory)
    {
        return _addAssetReqCurve(intent, addr, id, AssetType.ERC721, curve, relative);
    }

    /**
     * Add an end state required asset of ERC1155 tokens to the user intent.
     * @param intent The user intent to modify.
     * @param addr The address of the ERC1155 token contract.
     * @param id The ID of the ERC1155 token.
     * @param curve The curve parameters for the asset requirement.
     * @param relative Boolean flag to indicate if the curve is relative.
     * @return The updated user intent.
     */
    function addRequiredERC1155(
        UserIntent memory intent,
        address addr,
        uint256 id,
        int256[] memory curve,
        bool relative
    ) public pure returns (UserIntent memory) {
        return _addAssetReqCurve(intent, addr, id, AssetType.ERC1155, curve, relative);
    }

    /**
     * Encodes the asset based intent data onto the user intent.
     * @param intent The user intent to modify.
     * @param data The asset based intent standard data.
     * @return The updated user intent.
     */
    function encodeData(UserIntent memory intent, AssetBasedIntentData memory data)
        public
        pure
        returns (UserIntent memory)
    {
        bytes memory raw = abi.encode(data);
        bytes memory encoded = new bytes(raw.length - 32);
        for (uint256 i = 32; i < raw.length; i++) {
            encoded[i - 32] = raw[i];
        }

        intent.intentData = encoded;
        return intent;
    }

    /**
     * Decodes the asset based intent data from the user intent.
     * @param intent The user intent to decode data from.
     * @return The asset based intent data.
     */
    function decodeData(UserIntent memory intent) public pure returns (AssetBasedIntentData memory) {
        bytes memory raw = new bytes(intent.intentData.length + 32);
        assembly {
            mstore(add(raw, 32), 0x0000000000000000000000000000000000000000000000000000000000000020)
        }
        for (uint256 i = 0; i < intent.intentData.length; i++) {
            raw[i + 32] = intent.intentData[i];
        }
        (AssetBasedIntentData memory data) = abi.decode(raw, (AssetBasedIntentData));
        return data;
    }

    /**
     * Internal helper function to determine the type of the curve based on its parameters.
     */
    function getCurveType(int256[] memory params) internal pure returns (CurveType) {
        if (params.length == 4) return CurveType.EXPONENTIAL;
        if (params.length == 3) return CurveType.LINEAR;
        return CurveType.CONSTANT;
    }

    /**
     * Private helper function to add an asset release curve to a user intent.
     */
    function _addAssetReqCurve(
        UserIntent memory userIntent,
        address assetContract,
        uint256 assetId,
        AssetType assetType,
        int256[] memory curveParams,
        bool isRelative
    ) private pure returns (UserIntent memory) {
        AssetBasedIntentData memory data = decodeData(userIntent);

        //create new curve element
        EvaluationType evalType = EvaluationType.ABSOLUTE;
        if (isRelative) evalType = EvaluationType.RELATIVE;
        AssetBasedIntentCurve memory curve = AssetBasedIntentCurve({
            assetContract: assetContract,
            assetId: assetId,
            assetType: assetType,
            curveType: getCurveType(curveParams),
            evaluationType: evalType,
            params: curveParams
        });

        //clone previous array and add new element
        AssetBasedIntentCurve[] memory assetConstraints = new AssetBasedIntentCurve[](data.assetConstraints.length + 1);
        for (uint256 i = 0; i < data.assetConstraints.length; i++) {
            assetConstraints[i] = data.assetConstraints[i];
        }
        assetConstraints[data.assetConstraints.length] = curve;
        data.assetConstraints = assetConstraints;

        userIntent = encodeData(userIntent, data);
        return userIntent;
    }

    /**
     * Private helper function to add an asset requirement curve to a user intent.
     */
    function _addAssetReleaseCurve(
        UserIntent memory userIntent,
        address assetContract,
        uint256 assetId,
        AssetType assetType,
        int256[] memory curveParams
    ) private pure returns (UserIntent memory) {
        AssetBasedIntentData memory data = decodeData(userIntent);

        //create new curve element
        AssetBasedIntentCurve memory curve = AssetBasedIntentCurve({
            assetContract: assetContract,
            assetId: assetId,
            assetType: assetType,
            curveType: getCurveType(curveParams),
            evaluationType: EvaluationType.ABSOLUTE,
            params: curveParams
        });

        //clone previous array and add new element
        AssetBasedIntentCurve[] memory assetReleases = new AssetBasedIntentCurve[](data.assetReleases.length + 1);
        for (uint256 i = 0; i < data.assetReleases.length; i++) {
            assetReleases[i] = data.assetReleases[i];
        }
        assetReleases[data.assetReleases.length] = curve;
        data.assetReleases = assetReleases;

        userIntent = encodeData(userIntent, data);
        return userIntent;
    }
}

/**
 * @dev Helper function to generate curve parameters for a constant curve.
 * @param amount The constant value for the curve.
 * @return params The array containing the curve parameters.
 */
function constantCurve(int256 amount) pure returns (int256[] memory) {
    int256[] memory params = new int256[](1);
    params[0] = amount;
    return params;
}

/**
 * @dev Helper function to generate curve parameters for a linear curve.
 * @param m The slope of the linear curve.
 * @param b The y-intercept of the linear curve.
 * @param max The maximum x value for the curve. If negative, the curve should be evaluated from right to left.
 * @return params The array containing the curve parameters.
 */
function linearCurve(int256 m, int256 b, int256 max) pure returns (int256[] memory) {
    int256[] memory params = new int256[](3);
    params[0] = m;
    params[1] = b;
    params[2] = max;
    return params;
}

/**
 * @dev Helper function to generate curve parameters for an exponential curve.
 * @param m The multiplier for the exponential curve.
 * @param b The base for the exponential curve.
 * @param e The exponent for the exponential curve.
 * @param max The maximum x value for the curve. If negative, the curve should be evaluated from right to left.
 * @return params The array containing the curve parameters.
 */
function exponentialCurve(int256 m, int256 b, int256 e, int256 max) pure returns (int256[] memory) {
    int256[] memory params = new int256[](4);
    params[0] = m;
    params[1] = b;
    params[2] = e;
    params[3] = max;
    return params;
}
