// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/proxy/utils/Initializable.sol";
import "openzeppelin/proxy/utils/UUPSUpgradeable.sol";

import "../core/BaseAccount.sol";
import "./TokenCallbackHandler.sol";

contract Account is BaseAccount, TokenCallbackHandler, UUPSUpgradeable, Initializable {
    using ECDSA for bytes32;

    address public owner;

    IEntryPoint private immutable _entryPoint;

    event AccountInitialized(IEntryPoint indexed entryPoint, address indexed owner);
    event Executed(IEntryPoint indexed entryPoint, address indexed target, uint256 indexed value, bytes data);

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
    }

    /**
     * Execute a transaction called from entry point while the entry point is in intent executing state.
     */
    function execute(address _target, uint256 _value, bytes calldata _data) external {
        _requireFromEntryPoint();
        _requireIntentExecuting();
        _call(_target, _value, _data);
        emit Executed(_entryPoint, _target, _value, _data);
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
            return 1;
        }
        return 0;
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

    // Initializable
    function initialize(address anOwner) public initializer {
        owner = anOwner;
        emit AccountInitialized(_entryPoint, anOwner);
    }

    /**
     * Ensure the function call went through Account or owner
     */
    function _requireFromOwner() internal view {
        require(msg.sender == owner || msg.sender == address(this), "account: not Owner");
    }

    // UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal view override {
        _requireFromOwner();
        (newImplementation);
    }

    receive() external payable {}
}
