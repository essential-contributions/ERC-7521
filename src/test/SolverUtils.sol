// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {UserIntent} from "../interfaces/UserIntent.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
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
        IERC20(erc20Token).approve(address(testUniswap), type(uint256).max);
        IERC20(erc20Token).approve(address(wrappedNativeToken), type(uint256).max);
    }

    /**
     * Always returns successful.
     * @dev This contract is extremely unsafe as a wallet, but is useful as a temporary playground for solvers.
     */
    function validateUserIntent(UserIntent calldata, bytes32) external pure returns (IAggregator) {
        return IAggregator(address(0));
    }

    /**
     * Swap ERC20 tokens for ETH using Uniswap.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param amountOutMinimum The minimum amount of ETH expected after the swap.
     * @param recipient The address to receive the swapped ETH.
     */
    function swapERC20ForETH(address uniswap, address erc20, address weth, uint256 amountOutMinimum, address recipient)
        external
    {
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

        // send to recipient
        payable(recipient).transfer(amount);
    }

    /**
     * Swap ERC20 tokens for ETH and forward some ETH to another address.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param amountOutMinimum The minimum amount of ETH expected after the swap.
     * @param recipient The address to receive the swapped ETH (after forwarding).
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     */
    function swapERC20ForETHAndForward(
        address uniswap,
        address erc20,
        address weth,
        uint256 amountOutMinimum,
        address recipient,
        uint256 forwardAmount,
        address forwardTo
    ) external {
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
        payable(forwardTo).transfer(forwardAmount);

        // send the remainder recipient
        payable(recipient).transfer(amount - forwardAmount);
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
    
    /** 
     * Add a test to exclude this contract from coverage report
     * note: there is currently an open ticket to resolve this more gracefully
     * https://github.com/foundry-rs/foundry/issues/2988
     */
    function test() public {}
}
