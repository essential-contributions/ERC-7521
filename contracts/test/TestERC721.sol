// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721, Test {
    uint256 private constant _NFT_TOKEN_SEED = uint256(keccak256("ERC721_NFT_TOKEN_SEED"));
    uint256 private constant _NFT_COST = 1 ether;

    uint256 private _nftIncrementer = 0;
    uint256 private _lastBoughtNFT = 0;

    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC721("TST721", "TestERC721")
    {}

    function buyNFT(address to) external payable returns (uint256) {
        require(msg.value >= _NFT_COST, "Insufficient payment");
        _lastBoughtNFT = uint256(keccak256(abi.encode(_NFT_TOKEN_SEED, _nftIncrementer)));
        _nftIncrementer++;
        _mint(to, _lastBoughtNFT);
        return _lastBoughtNFT;
    }

    function sellNFT(address from, uint256 id) external {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not Authorized");
        require(_exists(id), "Invalid ID");
        _burn(id);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = msg.sender.call{value: _NFT_COST}("");
        require(success, "Payment failed");
    }

    function lastBoughtNFT() external view returns (uint256) {
        return _lastBoughtNFT;
    }

    function nextNFTForSale() external view returns (uint256) {
        return uint256(keccak256(abi.encode(_NFT_TOKEN_SEED, _nftIncrementer)));
    }

    function nftCost() external pure returns (uint256) {
        return _NFT_COST;
    }

    function testNothing() public {}
}
