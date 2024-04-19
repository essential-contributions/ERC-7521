// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {UserIntent} from "../interfaces/UserIntent.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {ExactInputSingleParams, TestUniswap} from "./TestUniswap.sol";
import {TestWrappedNativeToken} from "./TestWrappedNativeToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * Library with util actions to streamline intent solving.
 */
contract SolverUtils is IAccount {
    constructor(TestUniswap testUniswap, IERC20 erc20Token, IERC20 wrappedNativeToken) {
        // set token approvals
        erc20Token.approve(address(testUniswap), type(uint256).max);
        wrappedNativeToken.approve(address(testUniswap), type(uint256).max);
    }

    /**
     * Always returns successful.
     * @dev This contract is extremely unsafe as a wallet, but is useful as a temporary playground for solvers.
     */
    function validateUserIntent(UserIntent calldata, bytes32) external pure {
        //always valid
    }

    /**
     * Swap ERC20 tokens for ETH and forward some ETH to another address.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param recipient The address to receive the swapped ERC20 (after forwarding).
     * @param forwardAmount The amount of ERC20 to forward to another address.
     * @param forwardTo The address to forward the ERC20 to.
     */
    function swapETHForERC20AndForward(
        address uniswap,
        address erc20,
        address weth,
        address recipient,
        uint256 forwardAmount,
        address forwardTo
    ) external {
        uint256 balance = address(this).balance;

        // wrap
        TestWrappedNativeToken(payable(weth)).deposit{value: balance}();

        // swap tokens
        ExactInputSingleParams memory swapParams = ExactInputSingleParams({
            tokenIn: weth,
            tokenOut: erc20,
            fee: uint24(0),
            recipient: address(this),
            deadline: uint256(0),
            amountIn: balance,
            amountOutMinimum: balance,
            sqrtPriceLimitX96: uint160(0)
        });
        uint256 amount = TestUniswap(payable(uniswap)).exactInputSingle(swapParams);

        // forward some erc20
        IERC20(erc20).transfer(forwardTo, forwardAmount);

        // send the remainder recipient
        IERC20(erc20).transfer(recipient, amount - forwardAmount);
    }

    /**
     * Swap ERC20 tokens for ETH and forward some ETH to another address.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param recipient The address to receive the swapped ETH (after forwarding).
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     */
    function swapERC20ForETHAndForward(
        address uniswap,
        address erc20,
        address weth,
        address recipient,
        uint256 forwardAmount,
        address forwardTo
    ) external {
        uint256 balance = IERC20(erc20).balanceOf(address(this));

        // swap tokens
        ExactInputSingleParams memory swapParams = ExactInputSingleParams({
            tokenIn: erc20,
            tokenOut: weth,
            fee: uint24(0),
            recipient: address(this),
            deadline: uint256(0),
            amountIn: balance,
            amountOutMinimum: balance,
            sqrtPriceLimitX96: uint160(0)
        });
        uint256 amount = TestUniswap(payable(uniswap)).exactInputSingle(swapParams);

        // unwrap
        TestWrappedNativeToken(payable(weth)).withdraw(amount);

        // forward some eth
        payable(forwardTo).transfer(forwardAmount);

        // send the remainder recipient
        payable(recipient).transfer(amount - forwardAmount);
    }

    /**
     * Swap ERC20 tokens for ETH and forward some ETH to other addresses.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param amountOutMinimum The minimum amount of ETH expected after the swap.
     * @param recipient The address to receive the swapped ETH (after forwarding).
     * @param forwardAmounts The amount of ETH to forward to other addresses.
     * @param forwardTos The addresses to forward the ETH to.
     */
    function swapERC20ForETHAndForwardMulti(
        address uniswap,
        address erc20,
        address weth,
        uint256 amountOutMinimum,
        address recipient,
        uint256[] calldata forwardAmounts,
        address[] calldata forwardTos
    ) external {
        unchecked {
            // swap tokens
            ExactInputSingleParams memory swapParams = ExactInputSingleParams({
                tokenIn: erc20,
                tokenOut: weth,
                fee: uint24(0),
                recipient: address(this),
                deadline: uint256(0),
                amountIn: IERC20(erc20).balanceOf(address(this)),
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: uint160(0)
            });
            uint256 amount = TestUniswap(payable(uniswap)).exactInputSingle(swapParams);

            // unwrap
            TestWrappedNativeToken(payable(weth)).withdraw(amount);

            // forward some eth
            for (uint256 i = 0; i < forwardAmounts.length; i++) {
                payable(forwardTos[i]).transfer(forwardAmounts[i]);
                amount = amount - forwardAmounts[i];
            }

            // send the remainder recipient
            payable(recipient).transfer(amount);
        }
    }

    function transferERC20(address erc20, address recipient, uint256 amount) external {
        IERC20(erc20).transfer(recipient, amount);
    }

    function transferETH(address recipient, uint256 amount) external {
        payable(recipient).transfer(amount);
    }

    /**
     * Transfers all ETH to a given address.
     * @param to the address to send the assets to.
     */
    function transferAllETH(address to) external {
        uint256 amount = address(this).balance;
        payable(to).transfer(amount);
    }

    /**
     * Default receive function.
     */
    receive() external payable {}
}
