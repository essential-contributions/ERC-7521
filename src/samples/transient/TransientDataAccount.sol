// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {BaseAccount} from "../../core/BaseAccount.sol";
import {IAggregator} from "../../interfaces/IAggregator.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {IAccountProxy} from "../../interfaces/IAccountProxy.sol";
import {IIntentDelegate} from "../../interfaces/IIntentDelegate.sol";
import {UserIntent} from "../../interfaces/UserIntent.sol";
import {Exec} from "../../utils/Exec.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {Initializable} from "openzeppelin/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

/**
 * A minimal account that uses transient data.
 *  this is sample minimal account that uses transient data to allow the entrypoint to be picked by a user at sign time.
 *  has a single signer that can send requests through the entryPoint.
 */
contract TransientDataAccount is BaseAccount, UUPSUpgradeable, Initializable, IAccountProxy {
    using ECDSA for bytes32;

    address private _owner;

    event TransientDataAccountInitialized(address indexed owner);

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.  To upgrade EntryPoint,
     * a new implementation of TransientDataAccount must be deployed with the new EntryPoint address, then upgrading
     * the implementation by calling `upgradeTo()`
     */
    function initialize(address anOwner) public virtual initializer {
        _owner = anOwner;
        emit TransientDataAccountInitialized(_owner);
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        IEntryPoint entrypoint;
        assembly {
            entrypoint := tload(0)
        }
        return entrypoint;
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
        override
        returns (IAggregator)
    {
        IEntryPoint entrypoint = entryPoint();
        if (entrypoint == IEntryPoint(address(0))) {
            entrypoint = IEntryPoint(msg.sender);
            assembly {
                tstore(0, entrypoint)
            }
        } else if (entrypoint != IEntryPoint(msg.sender)) {
            revert("invalid entry point");
        }

        intentHash = keccak256(abi.encode(intentHash, entrypoint, block.chainid));
        bytes32 hash = intentHash.toEthSignedMessageHash();
        require(_owner == hash.recover(intent.signature), "invalid signature");
        return IAggregator(address(0));
    }

    /**
     * If asked, claim to be a proxy for the owner (owner is an EOA)
     * @return address the EOA this account is a proxy for.
     */
    function proxyFor() external view returns (address) {
        return _owner;
    }
    /**
     * clear all transient data
     * @dev important if a user or protocol wishes to use multiple entrypoints in a single transaction
     */

    function clearTransientData() external {
        assembly {
            tstore(0, 0)
        }
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
