// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable private-vars-leading-underscore */

import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";
import {AssetBasedIntentData, AssetBasedIntentDataLib} from "./AssetBasedIntentData.sol";
import {AssetCurve, AssetCurveLib} from "./AssetCurve.sol";


contract AssetBasedIntentStandard is IIntentStandard {

    uint256 private constant REVERT_REASON_MAX_LEN = 2048;

    function executeCallData1(UserIntent calldata userInt) external {
        AssetBasedIntentData memory data = AssetBasedIntentDataLib.parse(userInt);

        //TODO: remember asset balances for comparison with end state

        //execute
        if (data.callData1.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData1, REVERT_REASON_MAX_LEN);
        }

        //TODO: release tokens

    }

    function executeCallData2(UserIntent calldata userInt) external {
        AssetBasedIntentData memory data = AssetBasedIntentDataLib.parse(userInt);

        //execute
        if (data.callData2.length > 0) {
            Exec.callAndRevert(userInt.sender, data.callData2, REVERT_REASON_MAX_LEN);
        }
    }

    function verifyEndState(UserIntent calldata userInt) external {

        //TODO: implement end state check

    }

    function hash(UserIntent calldata userInt) external pure returns (bytes32) {
        return AssetBasedIntentDataLib.hash(userInt);
    }
}
