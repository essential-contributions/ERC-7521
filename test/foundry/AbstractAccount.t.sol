// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/ScenarioTestEnvironment.sol";

contract AbstractAccountTest is ScenarioTestEnvironment {
    using Erc20ReleaseIntentSegmentBuilder for Erc20ReleaseIntentSegment;

    function test_entryPoint() public {
        assertEq(address(_account.entryPoint()), address(_entryPoint));
    }

    function test_getNonce() public {
        // nonce in the beginning
        assertEq(_account.getNonce(), 0);

        // user's intent
        UserIntent memory intent = _intent();
        intent = _addCallSegment(intent, _accountClaimAirdropERC20(2 ether));
        intent = _addErc20ReleaseSegment(intent, address(_testERC20), CurveBuilder.constantCurve(int256(1 ether)));
        intent = _signIntent(intent);

        // solver's intent
        UserIntent memory solverIntent =
            _solverIntent(_solverSwapERC20ForETH(1 ether, address(_publicAddressSolver)), "", "", 1);

        // handle intents
        _entryPoint.handleIntents(_solution(intent, solverIntent));

        // nonce after execution
        assertEq(_account.getNonce(), 1);
    }

    function test_failExecuteMulti_invalidInputs() public {
        // targets.length != values.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](2);

        UserIntent memory intent = _intent();
        intent = _addCallSegment(
            intent, abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
        );
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent("", "", "", 0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_failExecuteMulti_invalidInputs2() public {
        // targets.length != datas.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](1);

        UserIntent memory intent = _intent();
        intent = _addCallSegment(
            intent, abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas)
        );
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent("", "", "", 0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed: invalid multi call inputs"
            )
        );
        _entryPoint.handleIntents(solution);
    }
}
