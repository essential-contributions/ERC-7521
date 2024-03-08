// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable func-name-mixedcase */

import "./utils/TransferEthScenario.sol";

/*
 * Runs tests for more complex scenarios
 */
contract TransferEth is TransferEthScenario {
    function setUp() public override {
        super.setUp();
        super.transferEth_setUp();
    }

    function test_transferEth() public {
        uint256 accountInitialERC20Balance = _testERC20.balanceOf(address(_account));
        uint256 accountInitialETHBalance = address(_account).balance;

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 transferAmount) = transferEth_run(false);

        //verify end state
        uint256 solverTokenBalance = _testERC20.balanceOf(_publicAddressSolver);
        assertEq(solverTokenBalance, erc20ReleaseAmount, "The solver ended up with incorrect token balance");

        uint256 userTokenBalance = _testERC20.balanceOf(address(_account));
        uint256 expectedUserTokenBalance = accountInitialERC20Balance - erc20ReleaseAmount;
        assertEq(userTokenBalance, expectedUserTokenBalance, "The user ended up with incorrect token balance");

        uint256 recipientBalance = address(_recipientAddress).balance;
        assertEq(recipientBalance, transferAmount, "The recipient did not get the expected ETH");

        uint256 userBalance = address(_account).balance;
        uint256 expectedUserBalance = accountInitialETHBalance - transferAmount;
        assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect ETH balance");
    }

    function test_transferEth_multi() public {
        uint256[] memory accountInitialERC20Balances = new uint256[](4);
        uint256[] memory accountInitialETHBalances = new uint256[](4);
        accountInitialERC20Balances[0] = _testERC20.balanceOf(address(_account));
        accountInitialETHBalances[0] = address(_account).balance;
        accountInitialERC20Balances[1] = _testERC20.balanceOf(address(_account2));
        accountInitialETHBalances[1] = address(_account2).balance;
        accountInitialERC20Balances[2] = _testERC20.balanceOf(address(_account3));
        accountInitialETHBalances[2] = address(_account3).balance;
        accountInitialERC20Balances[3] = _testERC20.balanceOf(address(_account4));
        accountInitialETHBalances[3] = address(_account4).balance;

        //execute a swap intent
        (uint256 erc20ReleaseAmount, uint256 transferAmount) = transferEth_run(true);

        //verify end state
        uint256 solverTokenBalance = _testERC20.balanceOf(_publicAddressSolver);
        assertEq(solverTokenBalance, erc20ReleaseAmount * 4, "The solver ended up with incorrect token balance");

        for (uint256 i = 0; i < 4; i++) {
            uint256 userTokenBalance = _testERC20.balanceOf(address(_account));
            uint256 expectedUserTokenBalance = accountInitialERC20Balances[i] - erc20ReleaseAmount;
            assertEq(userTokenBalance, expectedUserTokenBalance, "The user ended up with incorrect token balance");

            uint256 recipientBalance = address(_recipientAddress).balance;
            assertEq(recipientBalance, transferAmount, "The recipient did not get the expected ETH");

            uint256 userBalance = address(_account).balance;
            uint256 expectedUserBalance = accountInitialETHBalances[i] - transferAmount;
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect ETH balance");
        }
    }
}
