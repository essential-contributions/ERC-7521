// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "../utils/ScenarioTestEnvironment.sol";

/*
 * In this scenario, a user wants to transfer ETH and compensate for gas in an ERC-20 token
 *
 * Solution:
 * 1. the solver executes the operation and pockets the released tokens
 */
contract TransferEth is ScenarioTestEnvironment {
    uint256 private _accountInitialETHBalance = 1 ether;
    uint256 private _accountInitialERC20Balance = 10 ether;

    function _intentForCase(uint256 erc20ReleaseAmount, address ethRecipient, uint256 ethAmount)
        private
        view
        returns (UserIntent memory)
    {
        uint256 releaseDuration = 3000;
        uint256 releaseAt = 1000;
        int256 releaseStartAmount = 0;
        int256 releaseEndAmount = int256(erc20ReleaseAmount * (releaseDuration / releaseAt));
        uint256 callGasLimit = 100_000;

        //build intent
        UserIntent memory intent = _intent();
        intent = _addErc20ReleaseLinear(
            intent,
            uint48(block.timestamp - releaseAt),
            uint24(releaseDuration),
            releaseStartAmount,
            releaseEndAmount - releaseStartAmount
        );
        bytes memory executeTransferETH = abi.encodeWithSelector(_account.execute.selector, ethRecipient, ethAmount, "");
        intent = _addUserOp(intent, callGasLimit, executeTransferETH);
        intent = _addSequentialNonce(intent, 1);
        return intent;
    }

    function _solutionForCase(UserIntent memory intent, address erc20Recipient)
        private
        view
        returns (IntentSolution memory)
    {
        UserIntent memory solverIntent = IntentBuilder.create(erc20Recipient);
        return _solution(intent, solverIntent);
    }

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), _accountInitialERC20Balance);
        vm.deal(address(_account), _accountInitialETHBalance);
    }

    function test_transferETH() public {
        uint256 erc20ReleaseAmount = 1 ether;
        address erc20Recipient = _publicAddressSolver;
        uint256 ethAmount = 0.1 ether;
        address ethRecipient = _publicAddress;

        //build intent, solution and execute
        {
            UserIntent memory intent = _intentForCase(erc20ReleaseAmount, ethRecipient, ethAmount);
            intent = _signIntent(intent);

            IntentSolution memory solution = _solutionForCase(intent, erc20Recipient);

            _entryPoint.handleIntents(solution);
        }

        //verify end state
        {
            uint256 solverBalance = _testERC20.balanceOf(_publicAddressSolver);
            assertEq(solverBalance, erc20ReleaseAmount, "The solver ended up with incorrect token balance");
        }
        {
            uint256 solverBalance = _testERC20.balanceOf(address(_account));
            uint256 expectedUserBalance = _accountInitialERC20Balance - erc20ReleaseAmount;
            assertEq(solverBalance, expectedUserBalance, "The user ended up with incorrect token balance");
        }
        {
            uint256 recipientBalance = address(_publicAddress).balance;
            assertEq(recipientBalance, ethAmount, "The recipient didn't get the expected ETH");
        }
        {
            uint256 recipientBalance = address(_account).balance;
            uint256 expectedUserBalance = _accountInitialETHBalance - ethAmount;
            assertEq(recipientBalance, expectedUserBalance, "The user ended up with incorrect ETH balance");
        }
    }
}
