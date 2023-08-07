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
    /// The reported token descriptor does not match the corresponding task id.
    error MismatchedTask(); // 1e377d4c Hjd9TA==
    /// The operation cannot proceed because the token has the wrong presence.
    error NotPresent(); // faa85272 +qhScg==

    /// Uniquely identifies a particular NFT bound to its original holder.
    struct TokenDescriptor {
        address token;
        uint256 id;
        address holder;
    }

    enum TokenPresence {
        /// The token is not known to this bridge endpoint.
        Unknown,
        /// The token is known not to be on this network.
        Absent,
        /// The token is known to be on this network and is held by this endpoint.
        Endpoint,
        /// The token is known to be on this network and is held by an NFT wallet.
        Wallet
    }

    mapping(uint256 => TokenPresence) internal presences;

    struct EndpointConfig {
        uint64 taskAcceptorUpdateDelay;
        address initialTaskAcceptor;
    }

    constructor(
        EndpointConfig memory _c
    )
        DelegatedTaskAcceptorV1()
        SimpleTimelockedTaskAcceptorV1Proxy(_c.initialTaskAcceptor, _c.taskAcceptorUpdateDelay)
        TaskHubV1Notifier()
    {
        return;
    }

    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        TokenDescriptor memory desc = TokenDescriptor({
            token: msg.sender,
            id: _tokenId,
            holder: _from
        });
        if (!_tokenIsSupported(desc)) revert UnsupportedToken();
        presences[getTaskId(desc)] = TokenPresence.Endpoint;
        taskHub().notify();
        return IERC721Receiver.onERC721Received.selector;
    }

    function getTokenPresence(
        TokenDescriptor calldata _desc
    ) external view returns (TokenPresence) {
        return presences[getTaskId(_desc)];
    }

    function getPendingTokens(
        address _token,
        uint256 _start,
        uint256 _stop
    ) external view returns (uint256[] memory) {
        uint256[] memory tokens = _getHeldTokens(_token, _start, _stop);
        uint256 writeIndex = 0;
        for (uint256 i; i < tokens.length; ++i) {
            TokenDescriptor memory desc = TokenDescriptor({
                token: _token,
                id: tokens[i],
                holder: address(this)
            });
            if (presences[getTaskId(desc)] != TokenPresence.Endpoint) continue;
            tokens[writeIndex++] = tokens[i];
        }
        assembly {
            mstore(tokens, writeIndex) // unsafely set the array length
        }
        return tokens;
    }

    function getTaskId(TokenDescriptor memory _desc) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_desc)));
    }

    function _tokenIsSupported(TokenDescriptor memory _desc) internal virtual returns (bool);

    function _getHeldTokens(
        address _token,
        uint256 _start,
        uint256 _stop
    ) internal view virtual returns (uint256[] memory);

    function _beforeTaskResultsAccepted(
        uint256[] calldata _taskIds,
        bytes calldata,
        bytes calldata _report,
        address
    ) internal view virtual override {
        TokenDescriptor[] memory descs = abi.decode(_report, (TokenDescriptor[]));
        for (uint256 i; i < _taskIds.length; ++i) {
            if (getTaskId(descs[i]) != _taskIds[i]) revert MismatchedTask();
            if (presences[_taskIds[i]] == TokenPresence.Wallet) revert NotPresent();
        }
    }

    function _afterTaskResultsAccepted(
        uint256[] calldata _taskIds,
        bytes calldata _report,
        address,
        TaskIdSelector memory _sel
    ) internal override {
        uint256[] memory acceptedIxs = _sel.indices(_taskIds);
        TokenDescriptor[] memory descs = abi.decode(_report, (TokenDescriptor[]));
        for (uint256 i; i < acceptedIxs.length; ++i) {
            uint256 taskId = _taskIds[acceptedIxs[i]];
            TokenDescriptor memory desc = descs[acceptedIxs[i]];
            if (presences[taskId] == TokenPresence.Endpoint) {
                presences[taskId] = TokenPresence.Absent;
            } else {
                IERC721(desc.token).transferFrom(address(this), desc.holder, desc.id);
                presences[taskId] = TokenPresence.Wallet;
            }
        }
    }
}
