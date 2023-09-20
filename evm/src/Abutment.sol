// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TaskIdSelectorOps} from "escrin/tasks/v1/acceptors/TaskAcceptor.sol";
import {
    IdentityId,
    IIdentityRegistry,
    PermittedSubmitterTaskAcceptor
} from "escrin/tasks/v1/acceptors/PermittedSubmitterTaskAcceptor.sol";
import {TaskHubNotifier} from "escrin/tasks/v1/hub/TaskHubNotifier.sol";
import {Ownable, Ownable2Step} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC721Receiver} from "openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {
    IERC721,
    IERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import {ERC165Checker} from "openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {EnumerableSet} from "openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC721AQueryable} from "ERC721A/extensions/IERC721AQueryable.sol";

abstract contract Abutment is
    IERC721Receiver,
    PermittedSubmitterTaskAcceptor,
    TaskHubNotifier,
    Ownable2Step
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using TaskIdSelectorOps for TaskIdSelector;

    /// The token sent to the bridge contract is not supported or not approved.
    error UnsupportedToken(); // 6a172882 ahcogg==
    /// The reported token descriptor does not match the corresponding task id.
    error MismatchedTask(); // 1e377d4c Hjd9TA==
    /// The operation cannot proceed because the token has the wrong presence.
    error NotPresent(); // faa85272 +qhScg==
    /// This operation cannot be performed yet.
    error TooSoon(); // 6fed7d85 b+19hQ==

    enum Presence {
        Unknown,
        /// The token is known not to be on this network.
        Absent,
        /// The token is known to be on this network and is held by this abutment.
        Abutment,
        /// The token is known to be on this network and is held by an NFT wallet.
        Wallet
    }

    struct Collection {
        address remote;
        mapping(uint256 /* token id */ => bool) voted;
        uint64 approvingVotes;
        uint64 quorum;
    }

    struct Token {
        address owner;
        Presence presence;
    }

    struct BridgeAction {
        IERC721 token;
        uint256 tokenId;
        ActionEffect effect;
        // @dev only set when ActionEffect is Release
        address recipient;
    }

    enum ActionEffect {
        Unknown,
        Lock,
        Release
    }

    struct TrustedIdentity {
        IIdentityRegistry registry;
        IdentityId id;
    }

    event TrustedIdentityIncoming(TrustedIdentity identity);

    uint256 public immutable trustedIdentityUpdateDelay;
    TrustedIdentity public incomingTrustedIdentity;
    uint256 public incomingTrustedIdentityActiveTime;

    mapping(IERC721 => Collection) internal collections;
    mapping(IERC721 => mapping(uint256 => Token)) internal tokens;
    EnumerableSet.AddressSet private supportedCollections;

    constructor(
        address owner,
        uint256 trustedIdentityUpdateDelay_,
        address trustedIdentityRegistry,
        IdentityId trustedIdentityId
    ) Ownable(owner) PermittedSubmitterTaskAcceptor(trustedIdentityRegistry, trustedIdentityId) {
        trustedIdentityUpdateDelay = trustedIdentityUpdateDelay_;
    }

    /// Votes to take action on the token with the weight of the provided token IDs.
    function vote(IERC721 token, uint256[] calldata tokenIds) external {
        Collection storage coll = collections[token];
        if (coll.quorum == 0) revert UnsupportedToken();

        uint256 newApprovals;
        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 id = tokenIds[i];
            if (token.ownerOf(id) != msg.sender || coll.voted[id]) continue;
            coll.voted[id] = true;
            newApprovals++;
        }
        coll.approvingVotes += uint64(newApprovals);

        if (coll.approvingVotes >= coll.quorum) {
            _onBallotApproved(token);
        }
    }

    function onERC721Received(address, address from, uint256 tokenId, bytes calldata)
        external
        override
        notify
        returns (bytes4)
    {
        if (!supportedCollections.contains(msg.sender)) revert UnsupportedToken();
        IERC721 token = IERC721(msg.sender);
        _beforeReceiveToken(token, tokenId);
        tokens[token][tokenId] = Token({owner: from, presence: Presence.Abutment});
        return IERC721Receiver.onERC721Received.selector;
    }

    function getVoteStatus(IERC721 token) public view returns (uint256 approvals, uint256 quorum) {
        Collection storage coll = collections[token];
        if (coll.quorum == 0) revert UnsupportedToken();
        return (coll.approvingVotes, coll.quorum);
    }

    function getRemote(IERC721 token) external view returns (address) {
        Collection storage coll = collections[token];
        if (coll.remote == address(0)) revert UnsupportedToken();
        return coll.remote;
    }

    function getSupportedCollections() external view returns (IERC721[] memory) {
        IERC721[] memory nfts = new IERC721[](supportedCollections.length());
        for (uint256 i; i < nfts.length; ++i) {
            nfts[i] = IERC721(supportedCollections.at(i));
        }
        return nfts;
    }

    function getVotingTokens(address voter, IERC721 token)
        external
        view
        returns (uint256[] memory votingTokens)
    {
        Collection storage coll = collections[token];
        if (coll.quorum == 0) revert UnsupportedToken();
        uint256[] memory heldTokens = _enumerateTokensOf(voter, token);
        votingTokens = new uint256[](heldTokens.length);
        uint256 numVotingTokens;
        for (uint256 i; i < heldTokens.length; ++i) {
            uint256 id = heldTokens[i];
            if (token.ownerOf(id) != voter || coll.voted[id]) continue;
            votingTokens[numVotingTokens++] = id;
        }
        assembly {
            mstore(votingTokens, numVotingTokens)
        }
    }

    function getHeldTokens(address holder, IERC721 token)
        external
        view
        returns (uint256[] memory)
    {
        return _enumerateTokensOf(holder, token);
    }

    struct HeldToken {
        uint256 id;
        Presence presence;
    }

    function getTokensByHolder(address holder, IERC721 token)
        external
        view
        returns (HeldToken[] memory)
    {
        uint256[] memory abutmentTokens = _enumerateTokensOf(address(this), token);
        uint256[] memory holderTokens = _enumerateTokensOf(holder, token);
        uint256 maxTokens = abutmentTokens.length + holderTokens.length;
        HeldToken[] memory heldTokens = new HeldToken[](maxTokens);
        uint256 writeIndex;
        for (uint256 i; i < abutmentTokens.length; i++) {
            uint256 id = abutmentTokens[i];
            Token storage tok = tokens[token][id];
            if (tok.owner != holder) continue;
            heldTokens[writeIndex++] = HeldToken({id: id, presence: tok.presence});
        }
        for (uint256 i; i < holderTokens.length; i++) {
            uint256 id = holderTokens[i];
            heldTokens[writeIndex++] = HeldToken({id: id, presence: tokens[token][id].presence});
        }
        assembly {
            mstore(heldTokens, writeIndex)
        }
        return heldTokens;
    }

    function getTokenStatuses(IERC721 token, uint256[] calldata ids)
        external
        view
        returns (Token[] memory)
    {
        Token[] memory ts = new Token[](ids.length);
        for (uint256 i; i < ids.length; ++i) {
            ts[i] = tokens[token][ids[i]];
        }
        return ts;
    }

    function setTrustedIdentity(TrustedIdentity calldata identity) external onlyOwner {
        if (
            identity.registry == incomingTrustedIdentity.registry
                && IdentityId.unwrap(identity.id) == IdentityId.unwrap(incomingTrustedIdentity.id)
        ) {
            if (incomingTrustedIdentityActiveTime > block.timestamp) revert TooSoon();
            _setTrustedIdentity(address(identity.registry), identity.id);
            delete incomingTrustedIdentity;
            delete incomingTrustedIdentityActiveTime;
            return;
        }
        incomingTrustedIdentity = identity;
        incomingTrustedIdentityActiveTime = block.timestamp + trustedIdentityUpdateDelay;
        emit TrustedIdentityIncoming(identity);
    }

    function _addCollection(IERC721 token, address remoteToken, uint256 totalSupply) internal {
        Collection storage coll = collections[token];
        require(coll.quorum == 0, "already exists");
        require(
            remoteToken != address(0) && totalSupply > 0 && totalSupply < type(uint64).max,
            "invalid request"
        );
        (coll.remote, coll.quorum) = (remoteToken, uint64((totalSupply >> 1) + 1));
    }

    function _addCollectionSupport(IERC721 token) internal {
        supportedCollections.add(address(token));
    }

    function _removeCollectionSupport(IERC721 token) internal {
        supportedCollections.remove(address(token));
    }

    /// @dev An abstraction over IERC721Enumerable and ERC721AQueryable that gets all items owned by the abutment for a particular collection. This should work for all Oasis collections that are very small and do not need pagination. This could cost a lot of gas, so it should not be called in a tx.
    function _enumerateTokensOf(address holder, IERC721 token)
        internal
        view
        returns (uint256[] memory)
    {
        if (ERC165Checker.supportsInterface(address(token), type(IERC721Enumerable).interfaceId)) {
            IERC721Enumerable enumerableToken = IERC721Enumerable(address(token));
            uint256[] memory heldTokens = new uint256[](token.balanceOf(holder));
            for (uint256 i; i < heldTokens.length; ++i) {
                heldTokens[i] = enumerableToken.tokenOfOwnerByIndex(holder, i);
            }
            return heldTokens;
        }
        return IERC721AQueryable(address(token)).tokensOfOwner(holder);
    }

    function _onBallotApproved(IERC721 token) internal virtual;

    function _beforeReceiveToken(IERC721 token, uint256 id) internal view virtual {}

    function _afterTaskResultsAccepted(
        uint256[] calldata taskIds,
        bytes calldata report,
        TaskIdSelector memory selected
    ) internal override {
        uint256[] memory acceptedIxs = selected.indices(taskIds);
        BridgeAction[] memory actions = abi.decode(report, (BridgeAction[]));
        for (uint256 i; i < acceptedIxs.length; ++i) {
            BridgeAction memory action = actions[acceptedIxs[i]];
            Token storage token = tokens[action.token][action.tokenId];

            require(action.effect != ActionEffect.Unknown, "invalid submission");
            if (action.effect == ActionEffect.Lock) {
                if (token.presence != Presence.Abutment) continue;
                token.presence = Presence.Absent;
                continue;
            }
            // The token is being released.
            // It may not yet exist on this side of the bridge, which would make its presence unknown.
            if (token.presence != Presence.Unknown && token.presence != Presence.Absent) continue;
            action.token.transferFrom(address(this), action.recipient, action.tokenId);
            token.presence = Presence.Wallet;
        }
    }
}
