// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC1155/ERC1155.sol";

contract TestERC1155 is ERC1155 {
    uint256 private constant _FUNGIBLE_TOKEN_ID = 0x23309c07e3159574022c2c407df21c2dfb7a85d9a124ae86ceec214240fcd3f6;
    uint256 private constant _NFT_TOKEN_SEED = 0xb18df0169e4a96e45a6fe7942a140b19dd8f8d70dfe64a1ff09882ab29068174;
    uint256 private constant _NFT_COST = 1 ether;

    uint256 private _nftIncrimenter = 0;
    uint256 private _lastBoughtNFT = 0;

    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC1155("")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, _FUNGIBLE_TOKEN_ID, amount, "");
    }

    function buyNFT(address to) external payable returns (uint256) {
        require(msg.value >= _NFT_COST, "Insufficient payment");
        _lastBoughtNFT = uint256(keccak256(abi.encode(_NFT_TOKEN_SEED, _nftIncrimenter)));
        _nftIncrimenter++;
        _mint(to, _lastBoughtNFT, 1, "");
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
        return uint256(keccak256(abi.encode(_NFT_TOKEN_SEED, _nftIncrimenter)));
    }
}
