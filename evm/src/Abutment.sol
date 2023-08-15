// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TaskIdSelectorOps} from "escrin/tasks/acceptor/TaskAcceptor.sol";
import {DelegatedTaskAcceptorV1} from "escrin/tasks/acceptor/DelegatedTaskAcceptor.sol";
import {SimpleTimelockedTaskAcceptorV1Proxy} from "escrin/tasks/widgets/TaskAcceptorProxy.sol";
import {TaskHubV1Notifier} from "escrin/tasks/widgets/TaskHubNotifier.sol";
import {IERC721} from "openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {EnumerableSet} from "openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract Abutment is
    IERC721Receiver,
    DelegatedTaskAcceptorV1,
    SimpleTimelockedTaskAcceptorV1Proxy,
    TaskHubV1Notifier
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

    mapping(IERC721 => Collection) internal collections;
    mapping(IERC721 => mapping(uint256 => Token)) internal tokens;
    EnumerableSet.AddressSet private supportedCollections;

    struct AbutmentConfig {
        uint64 taskAcceptorUpdateDelay;
        address initialTaskAcceptor;
    }

    constructor(AbutmentConfig memory c)
        DelegatedTaskAcceptorV1()
        SimpleTimelockedTaskAcceptorV1Proxy(c.initialTaskAcceptor, c.taskAcceptorUpdateDelay)
    {}

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
        returns (bytes4)
    {
        if (!supportedCollections.contains(msg.sender)) revert UnsupportedToken();
        IERC721 token = IERC721(msg.sender);
        _beforeReceiveToken(token, tokenId);
        tokens[token][tokenId] = Token({owner: from, presence: Presence.Abutment});
        getTaskHub().notify();
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

    /// @dev An abstraction over IERC721Enumerable and ERC721AQueryable that gets all items owned by the abutment for a particular collection. This should work for all Oasis collections that are very small and do not need pagination. This could cost a lot of gas, so it should not be called in a tx.
    function getAbutmentTokens(IERC721 token) external view virtual returns (uint256[] memory);

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

    function _onBallotApproved(IERC721 token) internal virtual;

    function _beforeReceiveToken(IERC721 token, uint256 id) internal view virtual {}

    function _afterTaskResultsAccepted(
        uint256[] calldata taskIds,
        bytes calldata report,
        address,
        TaskIdSelector memory sel
    ) internal override {
        uint256[] memory acceptedIxs = sel.indices(taskIds);
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
