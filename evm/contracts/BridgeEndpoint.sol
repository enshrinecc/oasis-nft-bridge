// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {TaskIdSelectorOps} from "@escrin/evm/contracts/tasks/acceptor/TaskAcceptor.sol";
import {DelegatedTaskAcceptorV1} from "@escrin/evm/contracts/tasks/acceptor/DelegatedTaskAcceptor.sol";
import {SimpleTimelockedTaskAcceptorV1Proxy} from "@escrin/evm/contracts/tasks/widgets/TaskAcceptorProxy.sol";
import {TaskHubV1Notifier} from "@escrin/evm/contracts/tasks/widgets/TaskHubNotifier.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

abstract contract BridgeEndpoint is
    IERC721Receiver,
    DelegatedTaskAcceptorV1,
    SimpleTimelockedTaskAcceptorV1Proxy,
    TaskHubV1Notifier
{
    using TaskIdSelectorOps for TaskIdSelector;

    /// The token sent to the bridge contract is not supported or not approved.
    error UnsupportedToken(); // 6a172882 ahcogg==
    /// This operation cannot be performed yet.
    error TooSoon(); // 6fed7d85 b+19hQ==
    /// The token cannot be reclaimed because it is not present on this network.
    error NotPresent(); // faa85272 +qhScg==

    /// Uniquely identifies a particular NFT bound to its original holder.
    struct TokenDescriptor {
        address token;
        uint256 id;
        address holder;
    }

    enum Presence {
        Unknown,
        Absent,
        Present
    }

    struct TokenState {
        Presence presence;
        uint64 unlockTimestamp; // Nonzero only when `status` is `Present`
    }

    struct Config {
        uint64 bridgingTimeout;
        uint64 taskAcceptorUpdateDelay;
        address initialTaskAcceptor;
    }

    event BridgingRequested(address indexed token, uint256 indexed id, address indexed holder);
    event TokenReclaimed(address indexed token, uint256 indexed id, address indexed holder);

    /// The time in seconds during which bridging must occur before a sent token may be reclaimed. This aims to prevent any bugs in the bridge from making tokens inaccessible.
    uint256 public immutable bridgingTimeout;

    mapping(uint256 /* task id */ => TokenState) internal knownTokens;

    constructor(
        Config memory _c
    )
        DelegatedTaskAcceptorV1()
        SimpleTimelockedTaskAcceptorV1Proxy(_c.initialTaskAcceptor, _c.taskAcceptorUpdateDelay)
        TaskHubV1Notifier()
    {
        bridgingTimeout = _c.bridgingTimeout;
    }

    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) external returns (bytes4) {
        if (!_tokenIsSupported(msg.sender)) revert UnsupportedToken();

        TokenDescriptor memory desc = TokenDescriptor({
            token: msg.sender,
            id: _tokenId,
            holder: _from
        });
        knownTokens[getTaskId(desc)] = TokenState({
            presence: Presence.Present,
            unlockTimestamp: uint64(block.timestamp + bridgingTimeout)
        });

        taskHub().notify();
        emit BridgingRequested(desc.token, desc.id, desc.holder);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// Sends a token that is eligible to be reclaimed back to the original sender.
    function reclaimToken(TokenDescriptor calldata _desc) external {
        TokenState storage tokenState = knownTokens[getTaskId(_desc)];
        if (tokenState.presence != Presence.Present) revert NotPresent();
        if (block.timestamp < uint256(tokenState.unlockTimestamp)) revert TooSoon();
        IERC721(_desc.token).transferFrom(address(this), _desc.holder, _desc.id);
        emit TokenReclaimed(_desc.token, _desc.id, _desc.holder);
    }

    function getTaskId(TokenDescriptor memory desc) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(desc)));
    }

    function _tokenIsSupported(address token) internal virtual returns (bool);

    function _afterTaskResultsAccepted(
        uint256[] calldata _taskIds,
        bytes calldata,
        address,
        TaskIdSelector memory _sel
    ) internal override {
        uint256[] memory acceptedIxs = _sel.indices(_taskIds);
        for (uint256 i; i < acceptedIxs.length; ++i) {
            TokenState storage state = knownTokens[_taskIds[acceptedIxs[i]]];
            state.presence = state.presence == Presence.Present
                ? Presence.Absent
                : Presence.Present;
            state.unlockTimestamp = 0;
        }
    }
}
