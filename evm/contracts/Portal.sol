// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC721, IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {BridgeEndpoint} from "./BridgeEndpoint.sol";

contract Portal is BridgeEndpoint, Ownable2Step {
    /// The NFT has too many tokens to be supported by this bridge.
    error TooManyTokens();
    /// The token has already been proposed.
    error AlreadyProposed();

    struct SupportedToken {
        /// The token will become active once a majority of tokens have approved.
        uint64 approvals;
        uint64 quorum;
        uint64 deactivationTime;
        mapping(uint256 /* token id */ => bool) voted;
    }

    event TokenProposed(address indexed token, address indexed remote);
    event TokenApproved(address indexed token);

    /// The length of time in seconds that a supported token will remain able to be bridged by sending it to this bridge endpoint. Tokens can still be sent to this endpoint and retrieved.
    uint64 public immutable tokenSupportDuration;

    mapping(address => SupportedToken) public supportedTokens;

    constructor(
        EndpointConfig memory _endpointConfig,
        uint64 _tokenSupportDuration
    ) BridgeEndpoint(_endpointConfig) {
        tokenSupportDuration = _tokenSupportDuration;
    }

    /// Votes to support a token with all of the tokens held by the caller.
    function voteToSupportToken(address _tokenAddr) external {
        SupportedToken storage st = supportedTokens[_tokenAddr];
        if (st.quorum == 0) revert UnsupportedToken();

        IERC721Enumerable token = IERC721Enumerable(_tokenAddr);

        uint256 newApprovals;
        for (uint256 i; i < token.balanceOf(msg.sender); ++i) {
            uint256 heldTokenId = token.tokenOfOwnerByIndex(msg.sender, i);
            if (st.voted[heldTokenId]) continue;
            st.voted[heldTokenId] = true;
            newApprovals += 1;
        }
        st.approvals += uint64(newApprovals);

        if (st.approvals >= st.quorum) {
            st.deactivationTime = uint64(block.timestamp + tokenSupportDuration);
            emit TokenApproved(_tokenAddr);
        }
    }

    function proposeToken(address _token, address _remote) external onlyOwner {
        SupportedToken storage st = supportedTokens[_token];
        if (st.quorum != 0) revert AlreadyProposed();

        if (!ERC165Checker.supportsInterface(_token, type(IERC721Enumerable).interfaceId))
            revert UnsupportedToken();

        uint256 totalSupply = (IERC721Enumerable(_token).totalSupply() >> 1) + 1;
        if (totalSupply > type(uint64).max) revert TooManyTokens();

        st.quorum = uint64(totalSupply);
        emit TokenProposed(_token, _remote);
    }

    function _tokenIsSupported(TokenDescriptor memory _desc) internal view override returns (bool) {
        SupportedToken storage st = supportedTokens[_desc.token];
        return st.approvals >= st.quorum && st.deactivationTime > block.timestamp;
    }

    function _getHeldTokens(
        address _token,
        uint256 _start,
        uint256 _stop
    ) internal view override returns (uint256[] memory) {
        if (supportedTokens[_token].quorum == 0) {
            return new uint256[](0);
        }
        IERC721Enumerable token = IERC721Enumerable(_token);
        uint256 balance = token.balanceOf(address(this));
        uint256[] memory tokens = new uint256[](balance);
        uint256 inBounds = 0;
        for (uint256 i; i < balance; ++i) {
            uint256 id = token.tokenOfOwnerByIndex(address(this), i);
            if (id < _start || id >= _stop) continue;
            tokens[inBounds++] = id;
        }
        assembly {
            mstore(tokens, inBounds) // unsafely set the array length
        }
        return tokens;
    }

    /// @dev Tokens cannot be bridged back to the portal unless it was previously bridged from the portal by the same holder. This function reverts if an offending task result is found. The NFT contract must not accept such tokens, but we check again here for additional safety.
    function _beforeTaskResultsAccepted(
        uint256[] calldata _taskIds,
        bytes calldata,
        bytes calldata,
        address
    ) internal view override {
        for (uint256 i; i < _taskIds.length; ++i) {
            if (presences[_taskIds[i]] == TokenPresence.Unknown) revert UnsupportedToken();
        }
    }
}
