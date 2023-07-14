// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/core/NonceManager.sol";

contract NonceManagerHarness is NonceManager {
    function validateAndUpdateNonce(address sender, uint256 nonce) public returns (bool) {
        return _validateAndUpdateNonce(sender, nonce);
    }
}

library NonceManagerHelpers {
    function calculateNonce(uint256 sequenceNumber, uint192 key) public pure returns (uint256) {
        return (uint256(key) << 64) + sequenceNumber;
    }
}

contract NonceManagerTest is Test {
    NonceManagerHarness nonceManager;
    uint192 constant KEY = uint192(123);

    function setUp() public {
        nonceManager = new NonceManagerHarness();
    }

    function test_getNonce_sequenceNumberInitiallyZero() public {
        uint256 expectedNonce = NonceManagerHelpers.calculateNonce(0, KEY);
        uint256 nonce = nonceManager.getNonce(address(this), KEY);
        assertEq(nonce, expectedNonce);
    }

    function test_getNonce_gets() public {
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonceAfterIncrement = NonceManagerHelpers.calculateNonce(1, KEY);
        uint256 nonceAfterIncrement = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceAfterIncrement, expectedNonceAfterIncrement);
    }

    function test_getNonce_otherKeyNotAffected() public {
        uint192 key2 = uint192(456);
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonce2 = NonceManagerHelpers.calculateNonce(0, key2);
        uint256 nonce2 = nonceManager.getNonce(address(this), key2);
        assertEq(nonce2, expectedNonce2);
    }

    function test_incrementNonce_sequenceNumberInitiallyZero() public {
        uint256 expectedNonceInitial = NonceManagerHelpers.calculateNonce(0, KEY);
        uint256 nonceInitial = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceInitial, expectedNonceInitial);
    }

    function test_incrementNonce_increments() public {
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonceAfterIncrement = NonceManagerHelpers.calculateNonce(1, KEY);
        uint256 nonceAfterIncrement = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceAfterIncrement, expectedNonceAfterIncrement);
    }

    function test_incrementNonce_incrementsConcurrently() public {
        nonceManager.incrementNonce(KEY);
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonceAfterIncrement = NonceManagerHelpers.calculateNonce(2, KEY);
        uint256 nonceAfterIncrement = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceAfterIncrement, expectedNonceAfterIncrement);
    }

    function test_validateAndUpdateNonce_correct() public {
        uint256 nonce = NonceManagerHelpers.calculateNonce(0, KEY);
        bool result = nonceManager.validateAndUpdateNonce(address(this), nonce);
        uint256 expectedUpdatedNonce = NonceManagerHelpers.calculateNonce(1, KEY);
        uint256 updatedNonce = nonceManager.getNonce(address(this), KEY);
        assertEq(result, true);
        assertEq(updatedNonce, expectedUpdatedNonce);
    }

    function test_validateAndUpdateNonce_false() public {
        uint256 outdatedNonce = NonceManagerHelpers.calculateNonce(0, KEY);
        nonceManager.incrementNonce(KEY);
        bool result = nonceManager.validateAndUpdateNonce(address(this), outdatedNonce);
        uint256 expectedUpdatedNonce = NonceManagerHelpers.calculateNonce(2, KEY);
        uint256 updatedNonce = nonceManager.getNonce(address(this), KEY);
        assertEq(result, false);
        assertEq(updatedNonce, expectedUpdatedNonce);
    }
}
