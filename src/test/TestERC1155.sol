// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155, Test {
    uint256 private constant _FUNGIBLE_TOKEN_ID = uint256(keccak256("ERC1155_FUNGIBLE_TOKEN_ID"));
    uint256 private constant _NFT_TOKEN_SEED = uint256(keccak256("ERC1155_NFT_TOKEN_SEED"));
    uint256 private constant _NFT_COST = 1 ether;

    uint256 private _nftIncrementer = 0;
    uint256 private _lastBoughtNFT = 0;

    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC1155("")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, _FUNGIBLE_TOKEN_ID, amount, "");
    }

    function buyNFT(address to, uint256 amount) external payable returns (uint256) {
        require(msg.value >= _NFT_COST * amount, "Insufficient payment");
        _lastBoughtNFT = uint256(keccak256(abi.encode(_NFT_TOKEN_SEED, _nftIncrementer)));
        _nftIncrementer++;
        _mint(to, _lastBoughtNFT, amount, "");
        return _lastBoughtNFT;
    }

    function sellNFT(address from, uint256 id) external {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not Authorized");
        require(id != _FUNGIBLE_TOKEN_ID && balanceOf(from, id) == 1, "Invalid ID");
        _burn(from, id, 1);
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

    function test_nothing() public {}
}
