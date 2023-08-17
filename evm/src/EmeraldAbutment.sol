// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    IERC721,
    IERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC165Checker} from "openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {Abutment} from "./Abutment.sol";

contract EmeraldAbutment is Abutment {
    event TokenProposed(IERC721 indexed token);
    event TokenApproved(IERC721 indexed token);

    /// The length of time in seconds that a supported token will remain able to be bridged by sending it to this bridge endpoint. Tokens can still be sent to this endpoint and retrieved.
    uint256 internal immutable tokenSupportDuration_;

    mapping(IERC721 => uint256) public deactivationTimes;

    constructor(AbutmentConfig memory abutmentConfig, uint64 tokenSupportDuration)
        Abutment(abutmentConfig)
    {
        tokenSupportDuration_ = tokenSupportDuration;
    }

    function getTokenSupportDuration() external view returns (uint256) {
        return tokenSupportDuration_;
    }

    function proposeToken(address tokenAddr, address remoteAddr) external onlyOwner {
        if (!ERC165Checker.supportsInterface(tokenAddr, type(IERC721Enumerable).interfaceId)) {
            revert UnsupportedToken();
        }
        IERC721Enumerable token = IERC721Enumerable(tokenAddr);
        _addCollection(token, remoteAddr, token.totalSupply());
        emit TokenProposed(token);
    }

    function deactivateToken(IERC721 token) external {
        if (deactivationTimes[token] > block.timestamp) revert TooSoon();
        _removeCollectionSupport(token);
    }

    function _onBallotApproved(IERC721 token) internal override {
        deactivationTimes[token] = uint64(block.timestamp + tokenSupportDuration_);
        _addCollectionSupport(token);
        emit TokenApproved(token);
    }

    /// @dev Tokens cannot be bridged back to the Emerald abutment unless it was previously bridged from the portal by the same holder. This function reverts if an offending task result is found. The Saphire abutment must not accept such tokens, but we check again here for additional safety.
    function _beforeTaskResultsAccepted(
        uint256[] calldata,
        bytes calldata,
        bytes calldata report,
        address
    ) internal view override {
        BridgeAction[] memory actions = abi.decode(report, (BridgeAction[]));
        for (uint256 i; i < actions.length; ++i) {
            BridgeAction memory action = actions[i];
            if (tokens[action.token][action.tokenId].presence == Presence.Unknown) {
                revert UnsupportedToken();
            }
        }
    }
}
