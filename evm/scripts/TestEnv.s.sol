// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import {IdentityId, OmniKeyStore} from "escrin/identity/v1/OmniKeyStore.sol";
import {Permitter} from "escrin/identity/v1/permitters/Permitter.sol";
import {TaskAcceptorV1} from "escrin/tasks/acceptor/TaskAcceptor.sol";
import {TaskIdSelectorOps} from "escrin/tasks/acceptor/ITaskAcceptor.sol";
import {
    ERC721,
    ERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {Abutment} from "../src/Abutment.sol";
import {EmeraldAbutment} from "../src/EmeraldAbutment.sol";
import {SapphireAbutment} from "../src/SapphireAbutment.sol";

contract MockPermitter is Permitter {
    function _grantPermit(IdentityId, address, bytes calldata, bytes calldata)
        internal
        pure
        override
        returns (bool allow, uint64 expiry)
    {
        return (true, 0);
    }

    function _revokePermit(IdentityId, address, bytes calldata, bytes calldata)
        internal
        pure
        override
        returns (bool allow)
    {
        return true;
    }
}

contract MockTaskAcceptor is TaskAcceptorV1 {
    function _acceptTaskResults(uint256[] calldata, bytes calldata, bytes calldata, address)
        internal
        pure
        override
        returns (TaskIdSelector memory)
    {
        return TaskIdSelectorOps.all();
    }
}

contract MockERC721 is ERC721Enumerable {
    uint256 private nextTokenId;

    constructor() ERC721("MockToken", "MOCK") {}

    function mint(uint256 quantity, address to) external {
        for (uint256 i; i < quantity; ++i) {
            _mint(to, ++nextTokenId);
        }
    }
}

contract Setup is Script {
    modifier broadcasted() {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _;
        vm.stopBroadcast();
    }

    function _setupEmerald()
        internal
        broadcasted
        returns (EmeraldAbutment abutment, MockERC721 nft)
    {
        // Set up NFT
        nft = new MockERC721();
        console2.log("emerald NFT", address(nft));
        nft.mint(_getNftTotalSupply(), msg.sender);

        // Set up abutment
        TaskAcceptorV1 taskAcceptor = new MockTaskAcceptor();
        abutment = new EmeraldAbutment(Abutment.AbutmentConfig({
            taskAcceptorUpdateDelay: 7 days,
            initialTaskAcceptor: address(taskAcceptor)
        }), 16 weeks);
        console2.log("emerald abutment:", address(abutment));
    }

    function _setupSapphire(MockERC721 emeraldNft)
        internal
        broadcasted
        returns (SapphireAbutment abutment, MockERC721 nft)
    {
        nft = new MockERC721();
        console2.log("sapphire NFT", address(nft));

        // Setup up identity
        OmniKeyStore keyStore = new OmniKeyStore();
        Permitter permitter = new MockPermitter();
        IdentityId identityId = keyStore.createIdentity(address(permitter), "testing");
        console2.log("worker identity: %x", IdentityId.unwrap(identityId));

        // Set up abutment
        TaskAcceptorV1 taskAcceptor = new MockTaskAcceptor();
        abutment = new SapphireAbutment(Abutment.AbutmentConfig({
            taskAcceptorUpdateDelay: 7 days,
            initialTaskAcceptor: address(taskAcceptor)
        }));
        console2.log("sapphire abutment:", address(abutment));

        nft.mint(_getNftTotalSupply(), address(abutment));
        abutment.supportToken(address(nft), address(emeraldNft));
    }

    function _getNftTotalSupply() internal pure returns (uint256) {
        return 4;
    }
}

contract SetupSingleNetwork is Setup {
    function run() external {
        (EmeraldAbutment emeraldAbutment, MockERC721 emeraldNft) = _setupEmerald();
        (, MockERC721 sapphireNft) = _setupSapphire(emeraldNft);
        _completeSetup(emeraldAbutment, emeraldNft, sapphireNft);
    }

    function _completeSetup(
        EmeraldAbutment emeraldAbutment,
        MockERC721 emeraldNft,
        MockERC721 sapphireNft
    ) internal broadcasted {
        emeraldAbutment.proposeToken(address(emeraldNft), address(sapphireNft));

        uint256[] memory voice = new uint256[](emeraldNft.balanceOf(msg.sender));
        for (uint256 i; i < voice.length; ++i) {
            voice[i] = emeraldNft.tokenOfOwnerByIndex(msg.sender, i);
        }
        emeraldAbutment.vote(emeraldNft, voice);
        (uint256 approvals, uint256 quorum) = emeraldAbutment.getVoteStatus(emeraldNft);
        require(approvals >= quorum, "vote failed");

        emeraldNft.safeTransferFrom(msg.sender, address(emeraldAbutment), 1);
        emeraldNft.safeTransferFrom(msg.sender, address(emeraldAbutment), 2);
    }
}

contract SetupMultiNetwork is Setup {
    function run() external {
        uint256 emeraldFork = vm.createFork("localhost8546");
        uint256 sapphireFork = vm.createFork("hardhat");

        vm.selectFork(emeraldFork);
        (EmeraldAbutment emeraldAbutment, MockERC721 emeraldNft) = _setupEmerald();

        vm.selectFork(sapphireFork);
        (, MockERC721 sapphireNft) = _setupSapphire(emeraldNft);

        vm.selectFork(emeraldFork);
        _completeSetup(emeraldAbutment, emeraldNft, sapphireNft);
    }

    function _completeSetup(
        EmeraldAbutment emeraldAbutment,
        MockERC721 emeraldNft,
        MockERC721 sapphireNft
    ) internal broadcasted {
        emeraldAbutment.proposeToken(address(emeraldNft), address(sapphireNft));
    }
}
