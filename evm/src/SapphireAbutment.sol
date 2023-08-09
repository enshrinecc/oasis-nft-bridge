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

    constructor(AbutmentConfig memory _endpointConfig) Abutment(_endpointConfig) {}

    /// A convenience method that abstracts over IERC721Enumerable and ERC721AQueryable.
    function getAbutmentTokens(IERC721 _token) external view override returns (uint256[] memory) {
        if (ERC165Checker.supportsInterface(address(_token), type(IERC721Enumerable).interfaceId)) {
            IERC721Enumerable token = IERC721Enumerable(address(_token));
            uint256[] memory tokens = new uint256[](token.balanceOf(address(this)));
            for (uint256 i; i < tokens.length; ++i) {
                tokens[i] = token.tokenOfOwnerByIndex(address(this), i);
            }
            return tokens;
        }
        return IERC721AQueryable(address(_token)).tokensOfOwner(address(this));
    }

    // The caller must manually verify the details of the added contract.
    function supportToken(address _token, address _remote) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_token, type(IERC721).interfaceId)) {
            revert UnsupportedToken();
        }
        uint256 supply = IERC721Enumerable(_token).totalSupply(); // works for erc721a as well
        IERC721 token = IERC721(_token);
        require(token.balanceOf(address(this)) == supply, "not fully provisioned");
        _addCollection(token, _remote, IERC721Enumerable(_token).totalSupply());
        _addCollectionSupport(token);
        emit TokenSupported(token);
    }

    function transferUnclaimed(
        IERC721 _token,
        uint256[] calldata _tokenIds,
        address[] calldata _recipients
    ) external onlyOwner {
        if (!_isFrozen(_token)) revert TooSoon();
        require(_tokenIds.length == _recipients.length, "length mismatch");
        for (uint256 i; i < _tokenIds.length; ++i) {
            _token.safeTransferFrom(address(this), _recipients[i], _tokenIds[i]);
        }
    }

    function _isFrozen(IERC721 _token) internal view returns (bool) {
        (uint256 votes, uint256 quorum) = getVoteStatus(_token);
        return votes >= quorum;
    }

    function _onBallotApproved(IERC721 _token) internal override {
        _removeCollectionSupport(_token);
        emit TokenFrozen(_token);
    }

    function _beforeReceiveToken(IERC721 _token, uint256 _id) internal view override {
        if (tokens[IERC721(_token)][_id].presence == Presence.Unknown) revert UnsupportedToken();
    }
}
