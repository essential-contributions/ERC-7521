// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IBLSAccount} from "./IBLSAccount.sol";
import {BaseAccount} from "../../core/BaseAccount.sol";
import {IAggregator} from "../../interfaces/IAggregator.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {IProxyAccount} from "../../interfaces/IProxyAccount.sol";
import {IIntentDelegate} from "../../interfaces/IIntentDelegate.sol";
import {UserIntent} from "../../interfaces/UserIntent.sol";
import {Exec} from "../../utils/Exec.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

/**
 * Minimal BLS-based account that uses an aggregated signature.
 * The account must maintain its own BLS public key, and expose its trusted signature aggregator.
 */
contract BLSAccount is BaseAccount, UUPSUpgradeable, Initializable, IProxyAccount, IBLSAccount {
    using ECDSA for bytes32;

    IEntryPoint private immutable _entryPoint;
    IAggregator private immutable _aggregator;
    uint256[4] private _publicKey;
    address private _owner;

    event BLSAccountInitialized(
        IEntryPoint indexed entryPoint, IAggregator indexed aggregator, uint256[4] indexed publicKey
    );

    // The constructor is used only for the "implementation" and only sets immutable values.
    // Mutable value slots for proxy accounts are set by the 'initialize' function.
    constructor(IEntryPoint anEntryPoint, IAggregator anAggregator) {
        _entryPoint = anEntryPoint;
        _aggregator = anAggregator;
        _disableInitializers();
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of SimpleAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(uint256[4] calldata aPublicKey, address anOwner) public virtual initializer {
        _owner = anOwner;
        _publicKey = aPublicKey;
        emit BLSAccountInitialized(_entryPoint, _aggregator, _publicKey);
    }

    /// @inheritdoc IBLSAccount
    function getBlsPublicKey() public view override returns (uint256[4] memory) {
        return _publicKey;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * Validate user's intent (typically a signature)
     * @dev returning 0 indicates signature validated successfully.
     *
     * @param intent validate the intent.signature field
     * @param intentHash the hash of the intent, to check the signature against
     * @return aggregator (optional) trusted signature aggregator to return if signature fails
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash)
        external
        view
        override
        returns (IAggregator)
    {
        if (intent.signature.length > 0) {
            bytes32 hash = intentHash.toEthSignedMessageHash();
            if (_owner == hash.recover(intent.signature)) return IAggregator(address(0));
        }
        return _aggregator;
    }

    /**
     * If asked, claim to be a proxy for the owner (owner is an EOA)
     * @return address the EOA this account is a proxy for.
     */
    function proxyFor() external view returns (address) {
        return _owner;
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(address dest, uint256 value, bytes calldata func) external {
        _requireFromEntryPointOrOwner();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external {
        _requireFromEntryPointOrOwner();
        require(
            dest.length == func.length && (value.length == 0 || value.length == func.length),
            "wrong batch array lengths"
        );
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    function _onlyOwner() internal view {
        //directly from EOA owner, or through the account itself (which gets redirected through execute())
        require(msg.sender == _owner || msg.sender == address(this), "not account owner");
    }

    function _requireFromEntryPointOrOwner() internal view {
        require(msg.sender == address(_entryPoint) || msg.sender == _owner, "not account owner or entrypoint");
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        bool success = Exec.call(target, value, data, gasleft());
        if (!success) Exec.forwardRevert(Exec.REVERT_REASON_MAX_LEN);
    }

    function _authorizeUpgrade(address) internal view override {
        _onlyOwner();
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
