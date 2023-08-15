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
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        OmniKeyStore keyStore = new OmniKeyStore();

        TaskAcceptorV1 taskAcceptor = new MockTaskAcceptor();
        Permitter permitter = new MockPermitter();

        IdentityId identityId = keyStore.createIdentity(address(permitter), "testing");
        console.log(IdentityId.unwrap(identityId));

        Abutment.AbutmentConfig memory abutmentConfig = Abutment.AbutmentConfig({
            taskAcceptorUpdateDelay: 7 days,
            initialTaskAcceptor: address(taskAcceptor)
        });

        EmeraldAbutment emeraldAbutment = new EmeraldAbutment(abutmentConfig, 16 weeks);
        SapphireAbutment sapphireAbutment = new SapphireAbutment(abutmentConfig);

        MockERC721 emeraldNft = new MockERC721();
        MockERC721 sapphireNft = new MockERC721();

        emeraldNft.mint(4, msg.sender);

        emeraldAbutment.proposeToken(address(emeraldNft), address(sapphireNft));

        uint256[] memory voice = new uint256[](emeraldNft.balanceOf(msg.sender));
        for (uint256 i; i < voice.length; ++i) {
            voice[i] = emeraldNft.tokenOfOwnerByIndex(msg.sender, i);
        }
        emeraldAbutment.vote(emeraldNft, voice);
        (uint256 approvals, uint256 quorum) = emeraldAbutment.getVoteStatus(emeraldNft);
        require(approvals >= quorum, "vote failed");

        sapphireNft.mint(emeraldNft.totalSupply(), address(sapphireAbutment));
        sapphireAbutment.supportToken(address(sapphireNft), address(emeraldNft));

        emeraldNft.safeTransferFrom(msg.sender, address(emeraldAbutment), 1);
        emeraldNft.safeTransferFrom(msg.sender, address(emeraldAbutment), 2);

        vm.stopBroadcast();
    }
}
