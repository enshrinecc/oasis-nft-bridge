// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    Permitter,
    TrustedRelayerPermitter
} from "escrin/identity/v1/permitters/TrustedRelayerPermitter.sol";
import {
    IdentityId,
    PermittedSubmitterTaskAcceptorV1,
    TaskAcceptorV1
} from "escrin/tasks/acceptor/PermittedSubmitterTaskAcceptor.sol";

contract TrustMeBroAuthorizer is TrustedRelayerPermitter, PermittedSubmitterTaskAcceptorV1 {
    constructor(address trustedRelayer, address identityRegistry, IdentityId trustedIdentity)
        TrustedRelayerPermitter(trustedRelayer)
        PermittedSubmitterTaskAcceptorV1(identityRegistry, trustedIdentity)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Permitter, TaskAcceptorV1)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
