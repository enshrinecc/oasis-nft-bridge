// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    Permitter,
    TrustedRelayerPermitter
} from "escrin/identity/v1/permitters/TrustedRelayerPermitter.sol";

contract TrustMeBroPermitter is TrustedRelayerPermitter {
    constructor(address trustedRelayer) TrustedRelayerPermitter(trustedRelayer) {}
}
