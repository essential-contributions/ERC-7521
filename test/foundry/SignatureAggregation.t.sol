// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable func-name-mixedcase */

import "./utils/TokenSwapScenario.sol";
import "./utils/TransferErc20Scenario.sol";
import "./utils/TransferEthScenario.sol";

/*
 * Runs tests for more complex scenarios
 */
contract SignatureAggregation is TokenSwapScenario, TransferErc20Scenario, TransferEthScenario {
    function setUp() public override {
        super.setUp();
        super.tokenSwap_setUp();
        super.transferErc20_setUp();
        super.transferEth_setUp();
    }
}
