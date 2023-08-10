// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable2Step} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {
    IERC721,
    IERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC165Checker} from "openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import {Abutment} from "./Abutment.sol";

contract EmeraldAbutment is Abutment, Ownable2Step {
    event TokenProposed(IERC721 indexed token);
    event TokenApproved(IERC721 indexed token);

    /// The length of time in seconds that a supported token will remain able to be bridged by sending it to this bridge endpoint. Tokens can still be sent to this endpoint and retrieved.
    uint64 public immutable tokenSupportDuration;

    mapping(IERC721 => uint256) public deactivationTimes;

    constructor(AbutmentConfig memory _endpointConfig, uint64 _tokenSupportDuration)
        Abutment(_endpointConfig)
    {
        tokenSupportDuration = _tokenSupportDuration;
    }

    function getAbutmentTokens(IERC721 _token) external view override returns (uint256[] memory) {
        // All Emerald-side tokens were verified to support IERC721Enumerable before adding.
        IERC721Enumerable token = IERC721Enumerable(address(_token));
        uint256[] memory tokens = new uint256[](token.balanceOf(address(this)));
        for (uint256 i; i < tokens.length; ++i) {
            tokens[i] = token.tokenOfOwnerByIndex(address(this), i);
        }
        return tokens;
    }

    function proposeToken(address _token, address _remote) external onlyOwner {
        if (!ERC165Checker.supportsInterface(_token, type(IERC721Enumerable).interfaceId)) {
            revert UnsupportedToken();
        }
        IERC721 token = IERC721(_token);
        _addCollection(token, _remote, IERC721Enumerable(_token).totalSupply());
        emit TokenProposed(token);
    }

    function deactivateToken(IERC721 _token) external {
        if (deactivationTimes[_token] > block.timestamp) revert TooSoon();
        _removeCollectionSupport(_token);
    }

    function _onBallotApproved(IERC721 _token) internal override {
        deactivationTimes[_token] = uint64(block.timestamp + tokenSupportDuration);
        _addCollectionSupport(_token);
        emit TokenApproved(_token);
    }

    /// @dev Tokens cannot be bridged back to the Emerald abutment unless it was previously bridged from the portal by the same holder. This function reverts if an offending task result is found. The Saphire abutment must not accept such tokens, but we check again here for additional safety.
    function _beforeTaskResultsAccepted(
        uint256[] calldata,
        bytes calldata,
        bytes calldata _report,
        address
    ) internal view override {
        BridgeAction[] memory actions = abi.decode(_report, (BridgeAction[]));
        for (uint256 i; i < actions.length; ++i) {
            BridgeAction memory action = actions[i];
            if (tokens[action.token][action.tokenId].presence == Presence.Unknown) {
                revert UnsupportedToken();
            }
        }
    }
}
