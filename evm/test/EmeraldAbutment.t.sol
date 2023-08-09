// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";

import {
    ITaskAcceptorV1,
    TaskIdSelectorOps
} from "@escrin/evm/contracts/tasks/acceptor/TaskAcceptor.sol";
import {
    ERC721,
    ERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {Abutment} from "../contracts/Abutment.sol";
import {EmeraldAbutment} from "../contracts/EmeraldAbutment.sol";

contract UnsupportedNonEnumerableNFT is ERC721 {
    constructor() ERC721("Unsupported", "BAD") {
        return;
    }

    function test() public pure {
        return;
    }
}

contract UnsupportedUnreasonableNFT is ERC721Enumerable {
    constructor() ERC721("Unsupported", "BAD") {
        return;
    }

    function test() public pure {
        return;
    }

    function totalSupply() public pure override returns (uint256) {
        return type(uint256).max;
    }
}

contract MockNFT is ERC721Enumerable {
    uint256 private nextTokenId;

    constructor() ERC721("TestToken", "TEST") {
        return;
    }

    function test() public pure {
        return;
    }

    function mint(address to) external returns (uint256 id) {
        nextTokenId++;
        _mint(to, nextTokenId);
        return nextTokenId;
    }
}

contract EmeraldAbutmentTest is Test {
    using TaskIdSelectorOps for ITaskAcceptorV1.TaskIdSelector;

    address private constant NFT_OWNER_1 = address(2345);
    address private constant NFT_OWNER_10 = address(1234);
    // The quorum will be 6.

    EmeraldAbutment private p;
    MockNFT private nft;

    function setUp() public {
        p = new EmeraldAbutment(
            Abutment.AbutmentConfig({
                taskAcceptorUpdateDelay: 7 days,
                initialTaskAcceptor: address(42)
            }),
            12 weeks
        );
        nft = new MockNFT();

        nft.mint(NFT_OWNER_1);
        for (uint256 i; i < 10; ++i) {
            nft.mint(NFT_OWNER_10);
        }
    }

    function testProposeToken() public {
        // Ensure that only the portal owner can propose tokens.
        vm.prank(address(999));
        vm.expectRevert("Ownable: caller is not the owner");
        p.proposeToken(address(nft), address(888));

        // Ensure that only ERC721Enumerable are acceptable.
        ERC721 unsupportedNft = new UnsupportedNonEnumerableNFT();
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        p.proposeToken(address(unsupportedNft), address(888));

        // Ensure that only reasonable NFTs are acceptable.
        ERC721 unreasonableNft = new UnsupportedUnreasonableNFT();
        vm.expectRevert("invalid request");
        p.proposeToken(address(unreasonableNft), address(888));

        p.proposeToken(address(nft), address(888));
        // vm.expectEmit();
        // emit EmeraldAbutment.TokenProposed(address(nft));
        (uint256 votes, uint256 quorum) = p.getVoteStatus(nft);
        address remote = p.getRemote(nft);
        require(votes == 0 && quorum == 6 && remote == address(888), "proposal failed");
        // TODO

        vm.expectRevert("already exists");
        p.proposeToken(address(nft), address(888));
    }

    // function testBridgeComingFromWrongSender() public {
    //     p.proposeToken(address(nft), address(888));

    //     vm.prank(NFT_OWNER_10);
    //     p.vote(address(nft));

    //     vm.prank(NFT_OWNER_1);
    //     nft.safeTransferFrom(NFT_OWNER_1, address(p), 1);

    //     // First send the token over the bridge by NFT_OWNER_1.

    //     Abutment.TokenDescriptor memory desc = Abutment.TokenDescriptor({
    //         token: address(nft),
    //         id: 1,
    //         holder: NFT_OWNER_1
    //     });
    //     uint256[] memory taskIds = new uint256[](1);
    //     Abutment.TokenDescriptor[] memory report = new Abutment.TokenDescriptor[](1);
    //     taskIds[0] = p.getTaskId(desc);
    //     report[0] = desc;

    //     vm.mockCall(address(p.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
    //     p.acceptTaskResults(taskIds, "", abi.encode(report));

    //     // Now expect that the token cannot be bridged back by NFT_OWNER_10

    //     Abutment.TokenDescriptor memory unknownDesc = Abutment.TokenDescriptor({
    //         token: address(nft),
    //         id: 1,
    //         holder: NFT_OWNER_10
    //     });
    //     taskIds[0] = p.getTaskId(unknownDesc);
    //     report[0] = unknownDesc;
    //     vm.mockCall(address(p.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
    //     vm.expectRevert(Abutment.UnsupportedToken.selector);
    //     p.acceptTaskResults(taskIds, "", abi.encode(report));
    // }
}
