// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";

import {IdentityId, IdentityRegistry, OmniKeyStore} from "escrin/identity/v1/OmniKeyStore.sol";
import {Permitter} from "escrin/identity/v1/permitters/Permitter.sol";
import {
    ERC721,
    ERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {Abutment} from "../src/Abutment.sol";
import {EmeraldAbutment} from "../src/EmeraldAbutment.sol";
import {SapphireAbutment} from "../src/SapphireAbutment.sol";

contract MockPermitter is Permitter {
    constructor(IdentityRegistry registry) Permitter(registry) {}

    function _acquireIdentity(IdentityId, address, uint64, bytes calldata, bytes calldata)
        internal
        pure
        override
        returns (uint64 expiry)
    {
        return type(uint64).max;
    }

    function _releaseIdentity(IdentityId, address, bytes calldata, bytes calldata)
        internal
        pure
        override
    {}
}

contract MockERC721 is ERC721Enumerable {
    uint256 private nextTokenId;

    constructor() ERC721("MockToken", "MOCK") {}

    function mint(uint256 quantity, address to) external {
        for (uint256 i; i < quantity; ++i) {
            _mint(to, ++nextTokenId);
        }
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://airose.mypinata.cloud/ipfs/QmaWPWcxiETd9BwemjYkr6gQAakx5NuJtzS1qDKqY6PWos/";
    }
}

contract Setup is Script {
    modifier broadcasted() {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        _;
        vm.stopBroadcast();
    }

    address payable constant WORKER_OMNI_ADDR = payable(0x70884E7695cd256f075A18EB50232a488d897614);

    function _setupEmerald()
        internal
        broadcasted
        returns (EmeraldAbutment abutment, MockERC721 nft, Abutment.TrustedIdentity memory identity)
    {
        // Create IdentityRegistry and trusted identity
        IdentityRegistry reg = new IdentityRegistry();
        Permitter permitter = new MockPermitter(reg);
        IdentityId identityId = reg.createIdentity(address(permitter), "emerald identity");
        identity = Abutment.TrustedIdentity({registry: reg, id: identityId});
        console2.log("emerald identity registry:", address(reg));
        console2.log("emerald identity: %x", IdentityId.unwrap(identityId));

        // Set up NFT
        nft = new MockERC721();
        console2.log("emerald NFT", address(nft));
        nft.mint(_getNftTotalSupply(), msg.sender);

        // Set up abutment
        abutment = new EmeraldAbutment(msg.sender, 7 days, address(reg), identityId, 16 weeks);
        console2.log("emerald abutment:", address(abutment));

        WORKER_OMNI_ADDR.transfer(1 ether);
    }

    function _setupSapphire(MockERC721 emeraldNft)
        internal
        broadcasted
        returns (SapphireAbutment abutment, MockERC721 nft)
    {
        // Setup up identity
        OmniKeyStore keyStore = new OmniKeyStore();
        Permitter permitter = new MockPermitter(keyStore);
        IdentityId identityId = keyStore.createIdentity(address(permitter), "testing");
        console2.log("sapphire registry:", address(keyStore));
        console2.log("sapphire identity: %x", IdentityId.unwrap(identityId));

        nft = new MockERC721();
        console2.log("sapphire NFT", address(nft));

        // Set up abutment
        abutment = new SapphireAbutment(msg.sender, 7 days, address(keyStore), identityId);
        console2.log("sapphire abutment:", address(abutment));

        nft.mint(_getNftTotalSupply(), address(abutment));
        abutment.supportToken(address(nft), address(emeraldNft));

        WORKER_OMNI_ADDR.transfer(1 ether);
    }

    function _getNftTotalSupply() internal pure returns (uint256) {
        return 4;
    }
}

contract SetupSingleNetwork is Setup {
    function run() external {
        (EmeraldAbutment emeraldAbutment, MockERC721 emeraldNft,) = _setupEmerald();
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
        (EmeraldAbutment emeraldAbutment, MockERC721 emeraldNft,) = _setupEmerald();

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
        emeraldAbutment.vote(emeraldNft, emeraldAbutment.getVotingTokens(msg.sender, emeraldNft));
        emeraldNft.safeTransferFrom(msg.sender, address(emeraldAbutment), 1);
        emeraldNft.safeTransferFrom(msg.sender, address(emeraldAbutment), 2);
    }
}
