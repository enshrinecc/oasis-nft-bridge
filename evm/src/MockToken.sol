// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    ERC721,
    ERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockToken is ERC721Enumerable {
    constructor(address mintee) ERC721("MockToken", "MOCK") {
        for (uint256 i; i < 100; ++i) {
            _mint(mintee, i + 1);
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/QmaWPWcxiETd9BwemjYkr6gQAakx5NuJtzS1qDKqY6PWos/";
    }
}
