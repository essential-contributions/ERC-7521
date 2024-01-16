// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {TestWrappedNativeToken} from "./TestWrappedNativeToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/// @notice Interface code copied and modified from here:
/// https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
}

/// @notice Very basic simulation of what Uniswap does with the swaps for the unit tests on the TokenPaymaster
/// @dev Do not use to test any actual Uniswap interaction logic as this is way too simplistic
contract TestUniswap {
    TestWrappedNativeToken public weth;

    constructor(TestWrappedNativeToken _weth) {
        weth = _weth;
    }

    event StubUniswapExchangeEvent(uint256 amountIn, uint256 amountOut, address tokenIn, address tokenOut);

    function exactOutputSingle(ExactOutputSingleParams calldata params) external returns (uint256) {
        uint256 amountIn = params.amountInMaximum - 5;
        emit StubUniswapExchangeEvent(amountIn, params.amountOut, params.tokenIn, params.tokenOut);
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, params.amountOut);
        return amountIn;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external returns (uint256) {
        uint256 amountOut = params.amountOutMinimum + 5;
        emit StubUniswapExchangeEvent(params.amountIn, amountOut, params.tokenIn, params.tokenOut);
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, amountOut);
        return amountOut;
    }

    /// @notice Simplified code copied from here:
    /// https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/PeripheryPayments.sol#L19
    function unwrapWETH9(uint256 amountMinimum, address recipient) public payable {
        uint256 balanceWETH9 = weth.balanceOf(address(this));
        require(balanceWETH9 >= amountMinimum, "Insufficient WETH9");

        if (balanceWETH9 > 0) {
            weth.withdraw(balanceWETH9);
            payable(recipient).transfer(balanceWETH9);
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
