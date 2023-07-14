// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {AssetWrapper} from "../core/AssetWrapper.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IAssetRelease, AssetType} from "../interfaces/IAssetRelease.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";
import {AssetBasedIntentData, parseAssetBasedIntentData, AssetBasedIntentDataLib} from "./AssetBasedIntentData.sol";
import {AssetBasedIntentCurve, EvaluationType, AssetBasedIntentCurveLib} from "./AssetBasedIntentCurve.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";
import {ERC721Holder} from "openzeppelin/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "openzeppelin/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC777Recipient} from "openzeppelin/token/ERC777/IERC777Recipient.sol";
import {IERC1820Registry} from "openzeppelin/utils/introspection/IERC1820Registry.sol";
import {IERC1820Implementer} from "openzeppelin/utils/introspection/IERC1820Implementer.sol";

contract AssetBasedIntentStandard is
    IIntentStandard,
    IAssetRelease,
    ERC721Holder,
    ERC1155Holder,
    IERC777Recipient,
    IERC1820Implementer
{
    using AssetBasedIntentDataLib for AssetBasedIntentData;
    using AssetBasedIntentCurveLib for AssetBasedIntentCurve;
    using UserIntentLib for UserIntent;

    /**
     * Basic state and constants.
     */
    IEntryPoint private immutable _entryPoint;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Data for ERC-777 token support.
     */
    IERC1820Registry private _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant ERC777_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");
    bytes32 private constant ERC1820_ACCEPT_MAGIC = keccak256("ERC1820_ACCEPT_MAGIC");

    /**
     * Contract constructor.
     * @param entryPoint the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPoint) {
        _entryPoint = entryPoint;
        entryPoint.registerIntentStandard(this);

        // required for receiving ERC-777 tokens
        _erc1820.setInterfaceImplementer(address(this), ERC777_RECIPIENT_INTERFACE_HASH, address(this));
    }

    /**
     * Releases a user's asset(s) to the entryPoint contract.
     */
    function releaseAsset(AssetType assetType, address assetContract, uint256 assetId, address to, uint256 amount)
        external
        virtual
        override
    {
        require(msg.sender == address(_entryPoint), "standard: not from EntryPoint");
        require(
            AssetWrapper.balanceOf(assetType, assetContract, assetId, address(this)) >= amount,
            "standard: insufficient release balance"
        );

        AssetWrapper.transferFrom(assetType, assetContract, assetId, address(this), to, amount);
    }

    /**
     * Required implementation for receiving ERC-777 tokens.
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        // accept all ERC-777 tokens
    }

    /**
     * ERC1820 implementation required for receiving ERC-777 tokens.
     */
    function canImplementInterfaceForAddress(bytes32 interfaceHash, address account)
        public
        view
        virtual
        override
        returns (bytes32)
    {
        if (interfaceHash == ERC777_RECIPIENT_INTERFACE_HASH && account == address(this)) {
            return ERC1820_ACCEPT_MAGIC;
        }
        return bytes32(0x00);
    }

    /**
     * Default receive function.
     */
    receive() external payable {}

    /////////////////////////
    // DELEGATE/PURE CALLS //
    /////////////////////////

    /**
     * Validate intent structure (typically just formatting)
     * @param userInt the intent that is about to be solved.
     */
    function validateUserInt(UserIntent calldata userInt) external pure {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);

        //TODO: validate that "x" is not negative

        //validate curves
        data.validate();
    }

    function executeFirstPass(UserIntent calldata userInt, uint256 timestamp)
        external
        returns (bytes memory endContext)
    {
        IEntryPoint entryPoint = IEntryPoint(address(this));
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);

        //record starting balances
        uint256 constraintLen = data.assetConstraints.length;
        uint256[] memory startingBalances = new uint256[](constraintLen);
        for (uint256 i = 0; i < constraintLen; i++) {
            if (data.assetConstraints[i].evaluationType == EvaluationType.RELATIVE) {
                startingBalances[i] = AssetWrapper.balanceOf(
                    data.assetConstraints[i].assetType,
                    data.assetConstraints[i].assetContract,
                    data.assetConstraints[i].assetId,
                    userInt.sender
                );
            }
        }

        //execute
        if (data.callData1.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData1, data.callGasLimit1, REVERT_REASON_MAX_LEN);
        }

        //release tokens
        address releaseTo = address(entryPoint.getIntentStandardContract(userInt.getStandard()));
        uint256 evaluateAt = timestamp - data.timestamp;
        for (uint256 i = 0; i < data.assetReleases.length; i++) {
            int256 releaseAmount = data.assetReleases[i].evaluate(evaluateAt);
            if (releaseAmount < 0) releaseAmount = 0;
            IAssetRelease(userInt.sender).releaseAsset(
                data.assetReleases[i].assetType,
                data.assetReleases[i].assetContract,
                data.assetReleases[i].assetId,
                releaseTo,
                uint256(releaseAmount)
            );
        }

        // return list of starting balances for reference later
        return abi.encode(startingBalances);
    }

    // solhint-disable-next-line no-unused-vars
    function executeSecondPass(UserIntent calldata userInt, uint256 timestamp, bytes memory context)
        external
        returns (bytes memory endContext)
    {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);

        //execute
        if (data.callData2.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData2, data.callGasLimit2, REVERT_REASON_MAX_LEN);
        }

        //return unchanged context
        return context;
    }

    function verifyEndState(UserIntent calldata userInt, uint256 timestamp, bytes memory context) external view {
        AssetBasedIntentData calldata data = parseAssetBasedIntentData(userInt);
        uint256[] memory startingBalances = abi.decode(context, (uint256[]));

        //check end balances
        uint256 evaluateAt = timestamp - data.timestamp;
        for (uint256 i = 0; i < data.assetConstraints.length; i++) {
            int256 requiredBalance = data.assetConstraints[i].evaluate(evaluateAt);
            if (data.assetConstraints[i].evaluationType == EvaluationType.RELATIVE) {
                requiredBalance = int256(startingBalances[i]) + requiredBalance;
                if (requiredBalance < 0) requiredBalance = 0;
            }

            uint256 currentBalance = AssetWrapper.balanceOf(
                data.assetConstraints[i].assetType,
                data.assetConstraints[i].assetContract,
                data.assetConstraints[i].assetId,
                userInt.sender
            );
            require(
                currentBalance >= uint256(requiredBalance),
                string.concat(
                    "insufficient balance (required: ",
                    Strings.toString(requiredBalance),
                    ", current: ",
                    Strings.toString(currentBalance),
                    ")"
                )
            );
        }
    }
}
