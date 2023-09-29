// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721A} from "ERC721A/ERC721A.sol";
import {ERC721ABurnable} from "ERC721A/extensions/ERC721ABurnable.sol";
import {ERC721AQueryable} from "ERC721A/extensions/ERC721AQueryable.sol";

contract AIROSE is ERC721A, ERC721AQueryable, ERC721ABurnable {
    constructor(address abutment) ERC721A("AI ROSE", "AIROSE") {
        for (uint256 i; i < 111; i++) {
            _mintERC2309(abutment, 9);
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/QmSEfuX5f33Pxet1HHq536aDwAE6eMFR5kLtBqPDxz9XRH/";
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
