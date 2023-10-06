// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */
/* solhint-disable private-vars-leading-underscore */

import "./utils/TestEnvironment.sol";
import "../../src/test/NonceManagerHarness.sol";
import "../../src/core/NonceManager.sol";

contract NonceManagerTest is TestEnvironment {
    NonceManagerHarness nonceManager;
    uint192 constant KEY = uint192(123);

    function setUp() public override {
        super.setUp();
        nonceManager = new NonceManagerHarness();
    }

    function test_getNonce_sequenceNumberInitiallyZero() public {
        uint256 expectedNonce = nonceManager.calculateNonce(0, KEY);
        uint256 nonce = nonceManager.getNonce(address(this), KEY);
        assertEq(nonce, expectedNonce);
    }

    function test_getNonce_gets() public {
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonceAfterIncrement = nonceManager.calculateNonce(1, KEY);
        uint256 nonceAfterIncrement = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceAfterIncrement, expectedNonceAfterIncrement);
    }

    function test_getNonce_otherKeyNotAffected() public {
        uint192 key2 = uint192(456);
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonce2 = nonceManager.calculateNonce(0, key2);
        uint256 nonce2 = nonceManager.getNonce(address(this), key2);
        assertEq(nonce2, expectedNonce2);
    }

    function test_incrementNonce_sequenceNumberInitiallyZero() public {
        uint256 expectedNonceInitial = nonceManager.calculateNonce(0, KEY);
        uint256 nonceInitial = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceInitial, expectedNonceInitial);
    }

    function test_incrementNonce_increments() public {
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonceAfterIncrement = nonceManager.calculateNonce(1, KEY);
        uint256 nonceAfterIncrement = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceAfterIncrement, expectedNonceAfterIncrement);
    }

    function test_incrementNonce_incrementsConcurrently() public {
        nonceManager.incrementNonce(KEY);
        nonceManager.incrementNonce(KEY);
        uint256 expectedNonceAfterIncrement = nonceManager.calculateNonce(2, KEY);
        uint256 nonceAfterIncrement = nonceManager.getNonce(address(this), KEY);
        assertEq(nonceAfterIncrement, expectedNonceAfterIncrement);
    }

    function test_validateAndUpdateNonce_correct() public {
        uint256 nonce = nonceManager.calculateNonce(0, KEY);
        bool result = nonceManager.validateAndUpdateNonce(address(this), nonce);
        uint256 expectedUpdatedNonce = nonceManager.calculateNonce(1, KEY);
        uint256 updatedNonce = nonceManager.getNonce(address(this), KEY);
        assertEq(result, true);
        assertEq(updatedNonce, expectedUpdatedNonce);
    }

    function test_validateAndUpdateNonce_wrong() public {
        uint256 outdatedNonce = nonceManager.calculateNonce(0, KEY);
        nonceManager.incrementNonce(KEY);
        bool result = nonceManager.validateAndUpdateNonce(address(this), outdatedNonce);
        uint256 expectedUpdatedNonce = nonceManager.calculateNonce(2, KEY);
        uint256 updatedNonce = nonceManager.getNonce(address(this), KEY);
        assertEq(result, false);
        assertEq(updatedNonce, expectedUpdatedNonce);
    }
}
