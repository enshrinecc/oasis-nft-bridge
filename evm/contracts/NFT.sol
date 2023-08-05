// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ERC721A, ERC721AQueryable} from "erc721a/contracts/extensions/ERC721AQueryable.sol";

import {BridgeEndpoint} from "./BridgeEndpoint.sol";

contract NFT is ERC721AQueryable, BridgeEndpoint, Ownable2Step {
    /// This operation cannot be performed yet.
    error TooSoon(); // 6fed7d85 b+19hQ==

    event BridgeFrozen();

    uint128 public votesToFreeze;
    bool public frozen;

    string private baseURI_;

    struct NFTConfig {
        string name;
        string symbol;
        string baseURI;
        uint256 totalSupply;
    }

    constructor(
        NFTConfig memory _c,
        EndpointConfig memory _endpointConfig,
        uint256 mintBatchSize
    ) ERC721A(_c.name, _c.symbol) BridgeEndpoint(_endpointConfig) {
        baseURI_ = _c.baseURI;
        uint256 toMint = _c.totalSupply;
        while (toMint > 0) {
            uint256 quantity = toMint > mintBatchSize ? mintBatchSize : toMint;
            _mintERC2309(address(this), quantity);
            toMint -= quantity;
        }
    }

    /// Votes with the caller's tokens to freeze the bridge and end convertibility.
    function voteToFreezeBridge(uint256[] calldata _voice) external {
        uint256 newVotes;
        for (uint256 i; i < _voice.length; ++i) {
            TokenOwnership memory ownership = _ownershipAt(_voice[i]);
            bool voted = (ownership.extraData & 0x01) == 1;
            if (voted || ownership.addr != msg.sender) continue;
            newVotes += 1;
            _setExtraDataAt(_voice[i], ownership.extraData | 0x01);
        }
        uint256 totalVotesToFreeze = votesToFreeze + newVotes;
        votesToFreeze = uint128(totalVotesToFreeze);
        if (totalVotesToFreeze > (totalSupply() >> 1)) {
            frozen = true;
            emit BridgeFrozen();
        }
    }

    function transferUnclaimed(
        uint256[] calldata _tokenIds,
        address[] calldata _recipients
    ) external onlyOwner {
        if (!frozen) revert TooSoon();
        require(_tokenIds.length == _recipients.length, "length mismatch");
        for (uint256 i; i < _tokenIds.length; ++i) {
            safeTransferFrom(address(this), _recipients[i], _tokenIds[i]);
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _tokenIsSupported(TokenDescriptor memory _desc) internal view override returns (bool) {
        // The token is supported iff it was bridged in by the same holder.
        return presences[getTaskId(_desc)] != TokenPresence.Unknown && !frozen;
    }

    function _extraData(
        address,
        address,
        uint24 _previousExtraData
    ) internal pure override returns (uint24) {
        return _previousExtraData;
    }
}
