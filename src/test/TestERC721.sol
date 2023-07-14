// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721 {
    uint256 private constant _NFT_TOKEN_SEED = 0x09aa695c0d71bb929d9551218002d26e8c31a6028bdcfe77c0f4994d2287e545;
    uint256 private constant _NFT_COST = 1 ether;

    uint256 private _nftIncrimenter = 0;

    constructor()
        // solhint-disable-next-line no-empty-blocks
        ERC721("TST721", "TestERC721")
    {}

    function buyNFT(address to) external payable returns (uint256) {
        require(msg.value >= _NFT_COST, "Insufficient payment");
        uint256 nftId = uint256(keccak256(abi.encode(_NFT_TOKEN_SEED, _nftIncrimenter)));
        _nftIncrimenter++;
        _mint(to, nftId);
        return nftId;
    }

    function sellNFT(address from, uint256 id) external {
        require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "Not Authorized");
        require(_exists(id), "Invalid ID");
        _burn(id);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = msg.sender.call{value: _NFT_COST}("");
        require(success, "Payment failed");
    }
}
