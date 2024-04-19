// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IBLSAccount} from "./IBLSAccount.sol";
import {IBLSSignatureAggregator} from "./IBLSSignatureAggregator.sol";
import {BaseAccount} from "../../core/BaseAccount.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {IAccountProxy} from "../../interfaces/IAccountProxy.sol";
import {IIntentDelegate} from "../../interfaces/IIntentDelegate.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {Exec} from "../../utils/Exec.sol";
import {BLS} from "./lib/BLS.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

/**
 * Minimal BLS-based account that uses an aggregated signature.
 * The account must maintain its own BLS public key, and expose its trusted signature aggregator.
 */
contract BLSAccount is BaseAccount, UUPSUpgradeable, Initializable, IAccountProxy, IBLSAccount {
    using UserIntentLib for UserIntent;

    IEntryPoint private immutable _entryPoint;
    IBLSSignatureAggregator private immutable _aggregator;
    uint256[4] private _publicKey;
    address private _owner;

    bytes32 public constant BLS_DOMAIN = keccak256("erc7521.bls.domain");

    event BLSAccountInitialized(
        IEntryPoint indexed entryPoint, IBLSSignatureAggregator indexed aggregator, uint256[4] indexed publicKey
    );

    // The constructor is used only for the "implementation" and only sets immutable values.
    // Mutable value slots for proxy accounts are set by the 'initialize' function.
    constructor(IEntryPoint anEntryPoint, IBLSSignatureAggregator anAggregator) {
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
     */
    function validateUserIntent(UserIntent calldata intent, bytes32 intentHash) external view override {
        _requireFromEntryPoint();
        intentHash = keccak256(abi.encode(intentHash, _entryPoint, block.chainid));
        if (intent.signature.length > 0) {
            //verify signature
            uint256[2] memory signature = abi.decode(intent.signature, (uint256[2]));
            uint256[2] memory message = BLS.hashToPoint(BLS_DOMAIN, abi.encodePacked(intentHash));
            BLS.verifySingle(signature, _publicKey, message);
        } else {
            //check if validated in aggregate signature
            require(_aggregator.isValidated(intentHash), "invalid signature");
        }
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
        if (msg.sender != _owner) _requireFromIntentStandardExecutingForSender();
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
