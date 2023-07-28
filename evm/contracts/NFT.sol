// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {ERC721A, ERC721AQueryable} from "erc721a/contracts/extensions/ERC721AQueryable.sol";

import {BridgeEndpoint} from "./BridgeEndpoint.sol";

contract NFT is ERC721AQueryable, BridgeEndpoint {
    string private baseURI_;

    // Defined in https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol
    uint256 private constant _MAX_MINT_ERC2309_QUANTITY_LIMIT = 5000;

    struct NFTConfig {
        string name;
        string symbol;
        string baseURI;
        uint256 totalSupply;
    }

    constructor(
        NFTConfig memory _c,
        BridgeEndpoint.Config memory _endpointConfig
    ) ERC721A(_c.name, _c.symbol) BridgeEndpoint(_endpointConfig) {
        baseURI_ = _c.baseURI;
        uint256 toMint = _c.totalSupply;
        while (toMint > 0) {
            uint256 quantity = toMint > _MAX_MINT_ERC2309_QUANTITY_LIMIT
                ? _MAX_MINT_ERC2309_QUANTITY_LIMIT
                : toMint;
            _mintERC2309(address(this), quantity);
            toMint -= quantity;
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _tokenIsSupported(address _token) internal view override returns (bool) {
        return _token == address(this);
    }
}
