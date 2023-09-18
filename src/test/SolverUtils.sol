// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {TokenCallbackHandler} from "../wallet/TokenCallbackHandler.sol";
import {UserIntent} from "../interfaces/UserIntent.sol";
import {IAccount} from "../interfaces/IAccount.sol";
import {TestERC721} from "./TestERC721.sol";
import {ExactInputSingleParams, TestUniswap} from "./TestUniswap.sol";
import {TestWrappedNativeToken} from "./TestWrappedNativeToken.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * Library with util actions to streamline intent solving.
 */
contract SolverUtils is Test, TokenCallbackHandler, IAccount {
    constructor(TestUniswap testUniswap, IERC20 erc20Token, IERC20 wrappedNativeToken) {
        // set token approvals
        IERC20(erc20Token).approve(address(testUniswap), type(uint256).max);
        IERC20(erc20Token).approve(address(wrappedNativeToken), type(uint256).max);
    }

    /**
     * Always returns successful.
     * @dev This contract is extremely unsafe as a wallet, but is useful as a temporary playground for solvers.
     */
    function validateUserIntent(UserIntent calldata, bytes32) external pure returns (uint256) {
        return 0;
    }

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
     * Swap all ERC20 tokens for ETH and forward some ETH to another address.
     * @param uniswap The address of the Uniswap router contract.
     * @param erc721 The address of the ERC721 token contract to buy from.
     * @param erc20 The address of the ERC20 token to be swapped.
     * @param weth The address of the Wrapped Ether (WETH) token on Uniswap.
     * @param amountOutMinimum The minimum amount of ETH expected after the swap.
     * @param nftPrice The price required to buy the NFT.
     * @param forwardETHAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     */
    function swapAllERC20ForETHBuyNFTAndForward(
        address uniswap,
        address erc721,
        address erc20,
        address weth,
        uint256 amountOutMinimum,
        uint256 nftPrice,
        uint256 forwardETHAmount,
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

        // buy nft and forward
        uint256 tokenId = TestERC721(payable(erc721)).buyNFT{value: nftPrice}(address(this));
        TestERC721(payable(erc721)).transferFrom(address(this), forwardTo, tokenId);

        // forward some eth
        payable(forwardTo).transfer(forwardETHAmount);
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

    /**
     * Sell an ERC721 token for ETH and forward some ETH to another address.
     * @param erc721 The address of the ERC721 token contract to sell to.
     * @param tokenId The id of the token to sell.
     * @param forwardTo The address to forward the ETH to.
     */
    function sellERC721AndForwardAll(address erc721, uint256 tokenId, address forwardTo) external {
        // sell token
        TestERC721(payable(erc721)).sellNFT(address(this), tokenId);

        // forward all ETH
        uint256 amount = address(this).balance;
        payable(forwardTo).transfer(amount);
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

    function testNothing() public {}
}
