// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {BridgeEndpoint} from "./BridgeEndpoint.sol";

contract Bridge is BridgeEndpoint, Ownable {
    /// The NFT has too many tokens to be supported by this bridge.
    error TooManyTokens();

    struct SupportedToken {
        /// The token will become active once a majority of tokens have approved.
        uint64 approvals;
        uint64 quorum;
        uint64 deactivationTime;
        mapping(uint256 /* token id */ => bool) voted;
    }

    event TokenProposed(address indexed token);
    event TokenApproved(address indexed token);

    /// The length of time in seconds that a supported token will remain able to be bridged by sending it to this bridge endpoint. Tokens can still be sent to this endpoint and reclaimed.
    uint64 public immutable tokenSupportDuration;

    mapping(address => SupportedToken) public supportedTokens;

    constructor(
        BridgeEndpoint.Config memory _endpointConfig,
        uint64 _tokenSupportDuration
    ) BridgeEndpoint(_endpointConfig) {
        tokenSupportDuration = _tokenSupportDuration;
    }

    /// Votes to support a token with all of the tokens held by the caller.
    function supportToken(address _tokenAddr) external {
        SupportedToken storage supported = supportedTokens[_tokenAddr];
        IERC721Enumerable token = IERC721Enumerable(_tokenAddr);

        uint256 newApprovals = 0;
        for (uint256 i; i < token.balanceOf(msg.sender); ++i) {
            uint256 heldTokenId = token.tokenOfOwnerByIndex(msg.sender, i);
            if (supported.voted[heldTokenId]) continue;
            supported.voted[heldTokenId] = true;
            newApprovals += 1;
        }
        supported.approvals += uint64(newApprovals);

        if (_tokenIsSupported(_tokenAddr)) emit TokenApproved(_tokenAddr);
    }

    function proposeToken(address _token) external onlyOwner {
        if (supportedTokens[_token].quorum != 0) return; // Already proposed.
        if (!ERC165Checker.supportsInterface(_token, type(IERC721Enumerable).interfaceId))
            revert UnsupportedToken();
        uint256 totalSupply = (IERC721Enumerable(_token).totalSupply() >> 1) + 1;
        if (totalSupply > type(uint64).max) revert TooManyTokens();
        supportedTokens[_token].quorum = uint64(totalSupply);
        emit TokenProposed(_token);
    }

    function _tokenIsSupported(address _token) internal view override returns (bool) {
        SupportedToken storage st = supportedTokens[_token];
        return st.approvals >= st.quorum && st.deactivationTime > block.timestamp;
    }
}
