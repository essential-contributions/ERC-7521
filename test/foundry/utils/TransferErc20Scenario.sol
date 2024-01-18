// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "../utils/TestEnvironment.sol";
import "../../../src/standards/utils/CurveCoder.sol";

/*
 * In this scenario, a user wants to transfer ERC-20 tokens and compensate for gas with the same tokens
 *
 * Solution:
 * 1. the solver executes the operation and pockets the released tokens
 */
abstract contract TransferErc20Scenario is TestEnvironment {
    uint256 private _accountInitialERC20Balance = 10 ether;

    function transferErc20_setUp() public {
        //fund account
        _testERC20.mint(address(_account), _accountInitialERC20Balance);
        _testERC20.mint(address(_account2), _accountInitialERC20Balance);
        _testERC20.mint(address(_account3), _accountInitialERC20Balance);
        _testERC20.mint(address(_account4), _accountInitialERC20Balance);

        //set block timestamp to something reasonable
        vm.warp(1700952587);
    }

    function transferErc20_run() public returns (uint256 erc20ReleaseAmount, uint256 transferAmount) {
        erc20ReleaseAmount = 0.1 ether;
        transferAmount = 1 ether;
        address erc20Recipient = _publicAddressSolver;
        address transferRecipient = _publicAddress;

        //build intent
        UserIntent memory intent = _intentForTransferErc20(erc20ReleaseAmount, transferRecipient, transferAmount);
        intent = _signIntent(intent);

        //build solution
        IntentSolution memory solution = _solutionForTransferErc20(intent, erc20Recipient);

        //execute
        _entryPoint.handleIntents(solution);
    }

    ///////////////////////////////
    // Private Builder Functions //
    ///////////////////////////////

    function _intentForTransferErc20(uint256 erc20ReleaseAmount, address transferRecipient, uint256 transferAmount)
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
        intent = _addSequentialNonce(intent, 1);
        intent = _addErc20ReleaseLinear(
            intent,
            uint32(block.timestamp - releaseAt),
            uint16(releaseDuration),
            releaseStartAmount,
            (releaseEndAmount - releaseStartAmount) / int256(releaseDuration),
            false
        );
        bytes memory transferErc20 =
            abi.encodeWithSelector(_testERC20.transfer.selector, transferRecipient, transferAmount);
        bytes memory executeTransferErc20 =
            abi.encodeWithSelector(_account.execute.selector, _testERC20, 0, transferErc20);
        intent = _addUserOp(intent, callGasLimit, executeTransferErc20);
        return intent;
    }

    function _solutionForTransferErc20(UserIntent memory intent, address erc20Recipient)
        private
        view
        returns (IntentSolution memory)
    {
        UserIntent memory solverIntent = IntentBuilder.create(erc20Recipient);
        uint256[] memory order = new uint256[](4);
        order[0] = 0;
        order[1] = 0;
        order[2] = 1;
        order[3] = 0;
        return _solution(intent, solverIntent, order);
    }
}
