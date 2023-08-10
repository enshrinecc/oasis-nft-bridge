// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable2Step} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {
    IERC721,
    IERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC165Checker} from "openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {IERC721A, IERC721AQueryable} from "ERC721A/extensions/IERC721AQueryable.sol";

import {Abutment} from "./Abutment.sol";

contract SapphireAbutment is Abutment, Ownable2Step {
    event TokenSupported(IERC721 indexed token);
    event TokenFrozen(IERC721 indexed token);

    constructor(AbutmentConfig memory abutmentConfig) Abutment(abutmentConfig) {}

    /// A convenience method that abstracts over IERC721Enumerable and ERC721AQueryable.
    function getAbutmentTokens(IERC721 token) external view override returns (uint256[] memory) {
        if (ERC165Checker.supportsInterface(address(token), type(IERC721Enumerable).interfaceId)) {
            IERC721Enumerable enumerableToken = IERC721Enumerable(address(token));
            uint256[] memory tokens = new uint256[](token.balanceOf(address(this)));
            for (uint256 i; i < tokens.length; ++i) {
                tokens[i] = enumerableToken.tokenOfOwnerByIndex(address(this), i);
            }
            return tokens;
        }
        return IERC721AQueryable(address(token)).tokensOfOwner(address(this));
    }

    // The caller must manually verify the details of the added contract.
    function supportToken(address tokenAddr, address remoteAddr) external onlyOwner {
        if (!ERC165Checker.supportsInterface(tokenAddr, type(IERC721).interfaceId)) {
            revert UnsupportedToken();
        }
        IERC721Enumerable token = IERC721Enumerable(tokenAddr);
        _addCollection(token, remoteAddr, token.totalSupply());
        _addCollectionSupport(token);
        emit TokenSupported(token);
    }

    function transferUnclaimed(
        IERC721 token,
        uint256[] calldata tokenIds,
        address[] calldata recipients
    ) external onlyOwner {
        if (!_isFrozen(token)) revert TooSoon();
        require(tokenIds.length == recipients.length, "length mismatch");
        for (uint256 i; i < tokenIds.length; ++i) {
            token.safeTransferFrom(address(this), recipients[i], tokenIds[i]);
        }
    }

    function _isFrozen(IERC721 token) internal view returns (bool) {
        (uint256 votes, uint256 quorum) = getVoteStatus(token);
        return votes >= quorum;
    }

    function _onBallotApproved(IERC721 token) internal override {
        _removeCollectionSupport(token);
        emit TokenFrozen(token);
    }

    function _beforeReceiveToken(IERC721 token, uint256 id) internal view override {
        if (tokens[IERC721(token)][id].presence == Presence.Unknown) revert UnsupportedToken();
    }
}
