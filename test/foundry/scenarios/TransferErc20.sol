// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "../utils/TestEnvironment.sol";

/*
 * In this scenario, a user wants to transfer ERC-20 tokens and compensate for gas with the same tokens
 *
 * Solution:
 * 1. the solver executes the operation and pockets the released tokens
 */
contract TransferErc20 is TestEnvironment {
    uint256 private _accountInitialERC20Balance = 10 ether;

    function _intentForCase(uint256 erc20ReleaseAmount, address transferRecipient, uint256 transferAmount)
        private
        view
        returns (UserIntent memory)
    {
        uint256 releaseDuration = 3000;
        uint256 releaseAt = 1000;
        int256 releaseStartAmount = 0;
        int256 releaseEndAmount = int256(erc20ReleaseAmount * (releaseDuration / releaseAt));
        uint32 callGasLimit = 100_000;

        //build intent
        UserIntent memory intent = _intent();
        intent = _addErc20ReleaseLinear(
            intent,
            uint40(block.timestamp - releaseAt),
            uint32(releaseDuration),
            releaseStartAmount,
            (releaseEndAmount - releaseStartAmount) / int256(releaseDuration)
        );
        bytes memory transferErc20 =
            abi.encodeWithSelector(_testERC20.transfer.selector, transferRecipient, transferAmount);
        bytes memory executeTransferErc20 =
            abi.encodeWithSelector(_account.execute.selector, _testERC20, 0, transferErc20);
        intent = _addUserOp(intent, callGasLimit, executeTransferErc20);
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

        //set block timestamp to something reasonable
        vm.warp(1700952587);
    }

    function test_transferERC20() public {
        uint256 erc20ReleaseAmount = 0.1 ether;
        address erc20Recipient = _publicAddressSolver;
        uint256 transferAmount = 1 ether;
        address transferRecipient = _publicAddress;

        //build intent, solution and execute
        {
            UserIntent memory intent = _intentForCase(erc20ReleaseAmount, transferRecipient, transferAmount);
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
            uint256 userBalance = _testERC20.balanceOf(address(_account));
            uint256 expectedUserBalance = _accountInitialERC20Balance - (erc20ReleaseAmount + transferAmount);
            assertEq(userBalance, expectedUserBalance, "The user ended up with incorrect token balance");
        }
        {
            uint256 recipientBalance = _testERC20.balanceOf(address(_publicAddress));
            assertEq(recipientBalance, transferAmount, "The recipient didn't get the expected tokens");
        }
    }
}
