// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable func-name-mixedcase */

import "./utils/TransferErc20Scenario.sol";

/*
 * Runs tests for more complex scenarios
 */
contract TransferErc20 is TransferErc20Scenario {
    function setUp() public override {
        super.setUp();
        super.transferErc20_setUp();
    }

    function test_transferErc20() public {
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 transferAmount) = transferErc20_run(false, false);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(_publicAddressSolver);
        assertEq(solverBalance, erc20ReleaseAmount, "The solver ended up with incorrect token balance");

        uint256 userBalance = _testERC20.balanceOf(address(_account));
        uint256 expectedUserBalance = accountInitialERC20Balance - (erc20ReleaseAmount + transferAmount);
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect token balance");

        uint256 recipientBalance = _testERC20.balanceOf(address(_recipientAddress));
        assertEq(recipientBalance, transferAmount, "The recipient did not get the expected tokens");
    }

    function test_transferErc20_asProxy() public {
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_publicAddress));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 transferAmount) = transferErc20_run(true, false);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(_publicAddressSolver);
        assertEq(solverBalance, erc20ReleaseAmount, "The solver ended up with incorrect token balance");

        uint256 userBalance = _testERC20.balanceOf(address(_publicAddress));
        uint256 expectedUserBalance = accountInitialERC20Balance - (erc20ReleaseAmount + transferAmount);
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect token balance");

        uint256 recipientBalance = _testERC20.balanceOf(address(_recipientAddress));
        assertEq(recipientBalance, transferAmount, "The recipient did not get the expected tokens");
    }

    function test_transferErc20_registeredStandards() public {
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 transferAmount) = transferErc20_run(false, true);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(_publicAddressSolver);
        assertEq(solverBalance, erc20ReleaseAmount, "The solver ended up with incorrect token balance");

        uint256 userBalance = _testERC20.balanceOf(address(_account));
        uint256 expectedUserBalance = accountInitialERC20Balance - (erc20ReleaseAmount + transferAmount);
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect token balance");

        uint256 recipientBalance = _testERC20.balanceOf(address(_recipientAddress));
        assertEq(recipientBalance, transferAmount, "The recipient did not get the expected tokens");
    }

    function test_transferErc20_asProxyWithRegisteredStandards() public {
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_publicAddress));

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 transferAmount) = transferErc20_run(true, true);

        //verify end state
        uint256 solverBalance = _testERC20.balanceOf(_publicAddressSolver);
        assertEq(solverBalance, erc20ReleaseAmount, "The solver ended up with incorrect token balance");

        uint256 userBalance = _testERC20.balanceOf(address(_publicAddress));
        uint256 expectedUserBalance = accountInitialERC20Balance - (erc20ReleaseAmount + transferAmount);
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect token balance");

        uint256 recipientBalance = _testERC20.balanceOf(address(_recipientAddress));
        assertEq(recipientBalance, transferAmount, "The recipient did not get the expected tokens");
    }
}
