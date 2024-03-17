// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

/* solhint-disable func-name-mixedcase */

import "./utils/TestEnvironment.sol";
import "../../contracts/interfaces/IEntryPoint.sol";

contract SimpleAccountTest is TestEnvironment {
    function test_entryPoint() public {
        assertEq(address(_account.entryPoint()), address(_entryPoint));
    }

    function test_failValidation_notFromEntryPoint() public {
        UserIntent memory intent = _intent();

        vm.expectRevert("not from account EntryPoint");
        _account.validateUserIntent(intent, bytes32(0));
    }

    function test_failExecution_notFromExecutingIntentStandard() public {
        vm.expectRevert("entryPoint not executing intent standard for sender");
        _account.execute(address(0), uint256(0), "");
    }

    function test_failExecuteBatch_invalidInputs() public {
        // targets.length != values.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](1);
        bytes[] memory datas = new bytes[](2);

        UserIntent memory intent = _intent();
        bytes memory badCallData = abi.encodeWithSelector(SimpleAccount.executeBatch.selector, targets, values, datas);
        intent = _addSimpleCall(intent, badCallData);
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent());

        vm.expectRevert("wrong batch array lengths");
        _entryPoint.handleIntents(solution);
    }

    function test_failExecuteBatch_invalidInputs2() public {
        // targets.length != datas.length
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](1);

        UserIntent memory intent = _intent();
        bytes memory badCallData = abi.encodeWithSelector(SimpleAccount.executeBatch.selector, targets, values, datas);
        intent = _addSimpleCall(intent, badCallData);
        intent = _signIntent(intent);

        IntentSolution memory solution = _solution(intent, _solverIntent());

        vm.expectRevert("wrong batch array lengths");
        _entryPoint.handleIntents(solution);
    }
}
