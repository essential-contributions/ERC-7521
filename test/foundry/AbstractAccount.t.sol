// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./utils/ScenarioTestEnvironment.sol";
import "../../src/interfaces/IEntryPoint.sol";

contract AbstractAccountTest is ScenarioTestEnvironment {
    function test_entryPoint() public {
        assertEq(address(_account.entryPoint()), address(_entryPoint));
    }

    function test_failExecuteMulti_invalidInputs() public {
        // targets.length != values.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](2);

        UserIntent memory intent = _intent();
        bytes memory badCallData = abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas);
        intent = _addSimpleCall(intent, badCallData);
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
        bytes memory badCallData = abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas);
        intent = _addSimpleCall(intent, badCallData);
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
