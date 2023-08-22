// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {EntryPointTruster} from "../../core/EntryPointTruster.sol";
import {IIntentStandard} from "../../interfaces/IIntentStandard.sol";
import {IEntryPoint} from "../../interfaces/IEntryPoint.sol";
import {UserIntent, UserIntentLib} from "../../interfaces/UserIntent.sol";
import {Exec} from "../../utils/Exec.sol";
import {DefaultIntentData, parseDefaultIntentData} from "./DefaultIntentData.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

contract DefaultIntentStandard is IIntentStandard, EntryPointTruster {
    using UserIntentLib for UserIntent;

    /**
     * Basic state and constants.
     */
    IEntryPoint private immutable _entryPoint;
    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    /**
     * Contract constructor.
     * @param entryPointContract the address of the entrypoint contract
     */
    constructor(IEntryPoint entryPointContract) {
        _entryPoint = entryPointContract;
    }

    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function standardId() public view returns (bytes32) {
        return _entryPoint.getIntentStandardId(this);
    }

    /**
     * Default receive function.
     */
    receive() external payable {}

    /**
     * Validate intent structure (typically just formatting)
     * @param intent the intent that is about to be solved.
     */
    function validateUserIntent(UserIntent calldata intent) external pure {}

    /**
     * Performs part or all of the execution for an intent.
     * @param intent the intent to execute.
     * @param timestamp the time at which to evaluate the intent.
     * @param context context data from the previous step in execution (no data means execution is just starting).
     * @return context to remember for further execution (no data means execution has finished).
     */
    function executeUserIntent(UserIntent calldata intent, uint256 timestamp, bytes memory context)
        external
        onlyFromEntryPoint
        returns (bytes memory)
    {
        DefaultIntentData calldata data = parseDefaultIntentData(intent);

        //execute calldata
        if (data.callData.length > 0) {
            Exec.callAndRevert(intent.sender, data.callData, data.callGasLimit, REVERT_REASON_MAX_LEN);
        }

        return "";
    }

    /**
     * Verifies the intent standard is for a given entry point contract (required for registration on the entry point).
     * @param entryPointContract the entry point contract.
     * @return flag indicating if the intent standard is for the given entry point.
     */
    function isIntentStandardForEntryPoint(IEntryPoint entryPointContract) external view returns (bool) {
        return entryPointContract == _entryPoint;
    }
}
