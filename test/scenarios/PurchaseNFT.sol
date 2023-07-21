// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";

/*
 * In this scenario a user wants to buy an ERC1155 NFT using their ERC20 tokens.
 */
contract PurchaseNFT is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;

    function setUp() public override {
        super.setUp();

        //fund account
        _testERC20.mint(address(_account), 1000 ether);
    }

    function test_purchaseNFT() public {
        //create account intent
        bytes memory intentCallData1;
        bytes memory intentCallData2 = _accountBuyERC1155(1 ether);

        UserIntent memory userIntent = _createIntent(intentCallData1, intentCallData2);
        userIntent = userIntent.addReleaseERC20(address(_testERC20), constantCurve(2 ether));
        userIntent = _signIntent(userIntent);

        //create solution
        IEntryPoint.SolutionStep[] memory steps1 = _solverSwapERC20ForETH(2 ether, 2 ether, 1 ether, address(_account));
        IEntryPoint.SolutionStep[] memory steps2;

        IEntryPoint.IntentSolution memory solution = _createSolution(userIntent, steps1, steps2);

        //execute
        uint256 gasBefore = gasleft();
        _entryPoint.handleIntents(solution);
        console.log("Gas Consumed: %d", gasBefore - gasleft());

        //verify end state
        uint256 unusedBalance = address(_intentStandard).balance;
        uint256 unusedERC20Tokens = _testERC20.balanceOf(address(_intentStandard));
        uint256 solverERC20Tokens = _testERC20.balanceOf(_publicAddressSolver);
        uint256 solverWrappedNativeTokens = _testWrappedNativeToken.balanceOf(_publicAddressSolver);
        uint256 userERC20Tokens = _testERC20.balanceOf(address(_account));
        uint256 userERC1155Tokens = _testERC1155.balanceOf(address(_account), _testERC1155.lastBoughtNFT());
        uint256 userNativeBalance = address(_account).balance;
        assertEq(unusedBalance, 0, "There are native tokens still left in the token holder contract");
        assertEq(unusedERC20Tokens, 0, "There are ERC20 tokens still left in the token holder contract");
        assertEq(solverERC20Tokens, 0, "The solver ended up with unwanted ERC20 tokens");
        assertEq(
            solverWrappedNativeTokens,
            (1 ether) + 5,
            "The solver ended up with incorrect amount of wrapped native tokens"
        );
        assertEq(userERC20Tokens, 998 ether, "The user released more ERC20 tokens than expected");
        assertEq(userERC1155Tokens, 1, "The user did not get their NFT");
        assertEq(userNativeBalance, 0, "The user ended up with unwanted native tokens");
    }
}
