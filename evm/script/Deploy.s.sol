// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import {IdentityId, IIdentityRegistry} from "escrin/identity/v1/IIdentityRegistry.sol";
import {IPermitter} from "escrin/identity/v1/IPermitter.sol";
import {TrustedRelayerPermitter} from "escrin/identity/v1/permitters/TrustedRelayerPermitter.sol";
import {
    ERC721,
    ERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {Abutment} from "../src/Abutment.sol";
import {EmeraldAbutment} from "../src/EmeraldAbutment.sol";
import {SapphireAbutment} from "../src/SapphireAbutment.sol";

contract MockToken is ERC721Enumerable {
    constructor(address mintee) ERC721("MockToken", "MOCK") {
        for (uint256 i; i < 100; ++i) {
            _mint(mintee, i + 1);
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/QmaWPWcxiETd9BwemjYkr6gQAakx5NuJtzS1qDKqY6PWos/";
    }
}

contract DeployEmeraldTestnet is Script {
    function run() external {
        vm.startBroadcast();

        IIdentityRegistry reg = IIdentityRegistry(0x8998cC6D1ea9D07b002330606A6027aDB64798e6);
        IPermitter permitter = new TrustedRelayerPermitter(reg, msg.sender);
        IdentityId identityId = reg.createIdentity(address(permitter), "emerald identity");
        MockToken nft = new MockToken(msg.sender);
        EmeraldAbutment abutment =
            new EmeraldAbutment(msg.sender, 0 days, address(reg), identityId, 4 weeks);

        console2.log("emerald identity: %x", IdentityId.unwrap(identityId));
        console2.log("emerald NFT", address(nft));
        console2.log("emerald abutment:", address(abutment));

        vm.stopBroadcast();
    }
}

contract DeploySapphireTestnet is Script {
    function run() external {
        vm.startBroadcast();

        IIdentityRegistry keyStore = IIdentityRegistry(0x3C74f783A3F50651dD116eE8432B15B418607F23);
        IPermitter permitter = new TrustedRelayerPermitter(keyStore, msg.sender);

        vm.recordLogs();
        keyStore.createIdentity(address(permitter), "");
        IdentityId identityId = abi.decode(vm.getRecordedLogs()[0].data, (IdentityId));

        SapphireAbutment abutment =
            new SapphireAbutment(msg.sender, 0 days, address(keyStore), identityId);
        MockToken nft = new MockToken(address(abutment));

        console2.log("sapphire identity: %x", IdentityId.unwrap(identityId));
        console2.log("sapphire NFT", address(nft));
        console2.log("sapphire abutment:", address(abutment));

        vm.stopBroadcast();
    }
}

contract DeployEmeraldMainnet is Script {
    function run() external {
        vm.startBroadcast();

        address abutmentOwner = vm.envAddress("ABUTMENT_OWNER");

        IIdentityRegistry reg = IIdentityRegistry(0xFcfed3be2d333F24854cA8d3A351E772272D5842);
        IPermitter permitter = new TrustedRelayerPermitter(reg, msg.sender);
        IdentityId identityId = reg.createIdentity(address(permitter), "");
        EmeraldAbutment abutment =
            new EmeraldAbutment(msg.sender, 7 days, address(reg), identityId, 16 weeks);
        abutment.transferOwnership(abutmentOwner);

        console2.log("emerald identity: %x", IdentityId.unwrap(identityId));
        console2.log("emerald abutment:", address(abutment));

        vm.stopBroadcast();
    }
}

contract DeploySapphireMainnet is Script {
    function run() external {
        vm.startBroadcast();

        address abutmentOwner = vm.envAddress("ABUTMENT_OWNER");

        IIdentityRegistry keyStore = IIdentityRegistry(0x6e4039C3330681F91bC4bd394dc1a5AAE615FB36);
        IPermitter permitter = new TrustedRelayerPermitter(keyStore, msg.sender);

        vm.recordLogs();
        keyStore.createIdentity(address(permitter), "");
        IdentityId identityId = abi.decode(vm.getRecordedLogs()[0].data, (IdentityId));

        SapphireAbutment abutment =
            new SapphireAbutment(msg.sender, 7 days, address(keyStore), identityId);
        abutment.transferOwnership(abutmentOwner);

        console2.log("sapphire identity: %x", IdentityId.unwrap(identityId));
        console2.log("sapphire abutment:", address(abutment));

        vm.stopBroadcast();
    }
}
