// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./TestERC721.sol";
import "./TestUniswap.sol";
import "./TestWrappedNativeToken.sol";
import "../standards/assetbased/utils/AssetWrapper.sol";

/**
 * Library with util actions to streamline intent solving.
 */
contract SolverUtils {
    /**
     * Swap all ERC20 tokens for ETH using Uniswap.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param amountOutMinimum The minimum amount of ETH expected after the swap.
     * @param recipient The address to receive the swapped ETH.
     */
    function swapAllERC20ForETH(
        address uniswap,
        address erc20,
        address weth,
        uint256 amountOutMinimum,
        address recipient
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

        // send to recipient
        payable(recipient).transfer(amount);
    }

    /**
     * Swap all ERC20 tokens for ETH and forward some ETH to another address.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param amountOutMinimum The minimum amount of ETH expected after the swap.
     * @param recipient The address to receive the swapped ETH (after forwarding).
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     */
    function swapAllERC20ForETHAndForward(
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

    /**
     * Buy an ERC721 token and forward to a specific address.
     * @param erc721 The address of the ERC721 token contract to buy from.
     * @param forwardTo The address to forward the token to.
     */
    function buyERC721(address erc721, uint256 price, address forwardTo) external {
        // buy token
        uint256 tokenId = TestERC721(payable(erc721)).buyNFT{value: price}(address(this));

        // forward
        TestERC721(payable(erc721)).transferFrom(address(this), forwardTo, tokenId);
    }
}
