// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IdentityId, IdentityRegistry} from "escrin/identity/v1/IdentityRegistry.sol";
import {ERC721} from "openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockNFT is ERC721Enumerable {
    uint256 private nextTokenId;

    constructor() ERC721("TestToken", "TEST") {}

    function test() public pure {}

    function mint(address _to) external returns (uint256 id) {
        nextTokenId++;
        _mint(_to, nextTokenId);
        return nextTokenId;
    }
}

contract MockIdentityRegistry is IdentityRegistry {
    function test() public pure {}

    function _whenIdentityCreated(IdentityId id, bytes calldata pers) internal virtual override {}

    function _whenIdentityDestroyed(IdentityId id) internal virtual override {}
}

function makeTaskIds(uint256 count) pure returns (uint256[] memory) {
    uint256[] memory ids = new uint256[](count);
    for (uint256 i; i < count; ++i) {
        ids[i] = i;
    }
    return ids;
}
