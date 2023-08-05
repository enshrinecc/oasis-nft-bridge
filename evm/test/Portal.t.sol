// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";

import {ITaskAcceptorV1, TaskIdSelectorOps} from "@escrin/evm/contracts/tasks/acceptor/TaskAcceptor.sol";
import {ERC721, ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {BridgeEndpoint} from "../contracts/BridgeEndpoint.sol";
import {Portal} from "../contracts/Portal.sol";

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

contract PortalTest is Test {
    using TaskIdSelectorOps for ITaskAcceptorV1.TaskIdSelector;

    address private constant NFT_OWNER_1 = address(2345);
    address private constant NFT_OWNER_10 = address(1234);
    // The quorum will be 6.

    Portal private p;
    MockNFT private nft;

    function setUp() public {
        p = new Portal(
            BridgeEndpoint.EndpointConfig({
                taskAcceptorUpdateDelay: 7 days,
                initialTaskAcceptor: address(42)
            }),
            12 weeks
        );
        nft = new MockNFT();

        nft.mint(NFT_OWNER_1);
        for (uint256 i; i < 10; ++i) nft.mint(NFT_OWNER_10);
    }

    function testProposeToken() public {
        // Ensure that only the portal owner can propose tokens.
        vm.prank(address(999));
        vm.expectRevert("Ownable: caller is not the owner");
        p.proposeToken(address(nft), address(888));

        // Ensure that only ERC721Enumerable are acceptable.
        ERC721 unsupportedNft = new UnsupportedNonEnumerableNFT();
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        p.proposeToken(address(unsupportedNft), address(888));

        // Ensure that only reasonable NFTs are acceptable.
        ERC721 unreasonableNft = new UnsupportedUnreasonableNFT();
        vm.expectRevert(Portal.TooManyTokens.selector);
        p.proposeToken(address(unreasonableNft), address(888));

        p.proposeToken(address(nft), address(888));
        // vm.expectEmit();
        // emit Portal.TokenProposed(address(nft));
        (, uint256 quorum, ) = p.supportedTokens(address(nft));
        require(quorum == 6, "proposal failed");

        vm.expectRevert(Portal.AlreadyProposed.selector);
        p.proposeToken(address(nft), address(888));
    }

    function testApproveToken() public {
        p.proposeToken(address(nft), address(888));

        // Check that token is not yet supported as it is not yet approved.
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        vm.prank(NFT_OWNER_1);
        nft.safeTransferFrom(NFT_OWNER_1, address(p), 1);

        // Ensure that unknown tokens cannot be voted on.
        vm.prank(NFT_OWNER_10);
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        p.voteToSupportToken(address(555555));

        // Vote to support with 1 token.
        vm.prank(NFT_OWNER_1);
        p.voteToSupportToken(address(nft));
        (uint256 approvals1, , ) = p.supportedTokens(address(nft));
        require(approvals1 == 1, "vote to support failed");

        // Ensure that voting twice doesn't work.
        vm.prank(NFT_OWNER_1);
        p.voteToSupportToken(address(nft));
        (approvals1, , ) = p.supportedTokens(address(nft));
        require(approvals1 == 1, "vote to support failed");

        // Check that token is still not yet supported as been met.
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        vm.prank(NFT_OWNER_1);
        nft.safeTransferFrom(NFT_OWNER_1, address(p), 1);

        // Vote to support with 10 token.
        vm.prank(NFT_OWNER_10);
        p.voteToSupportToken(address(nft));
        (uint256 approvals2, , uint256 deactivationTime) = p.supportedTokens(address(nft));
        // vm.expectEmit();
        // emit Portal.TokenApproved(address(nft));
        require(approvals2 == 11, "vote to support failed");
        require(
            deactivationTime == block.timestamp + p.tokenSupportDuration(),
            "deactivationTime not set"
        );

        // Expect that sending will succeed after the token is active.
        vm.prank(NFT_OWNER_1);
        nft.safeTransferFrom(NFT_OWNER_1, address(p), 1);
        require(nft.ownerOf(1) == address(p), "transfer failed");

        // The sending should fail once the token has been deactivated.
        vm.warp(deactivationTime);
        vm.prank(NFT_OWNER_10);
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        nft.safeTransferFrom(NFT_OWNER_10, address(p), 2);
    }

    function testBridgeComingFromWrongSender() public {
        p.proposeToken(address(nft), address(888));

        vm.prank(NFT_OWNER_10);
        p.voteToSupportToken(address(nft));

        vm.prank(NFT_OWNER_1);
        nft.safeTransferFrom(NFT_OWNER_1, address(p), 1);

        // First send the token over the bridge by NFT_OWNER_1.

        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: 1,
            holder: NFT_OWNER_1
        });
        uint256[] memory taskIds = new uint256[](1);
        BridgeEndpoint.TokenDescriptor[] memory report = new BridgeEndpoint.TokenDescriptor[](1);
        taskIds[0] = p.getTaskId(desc);
        report[0] = desc;

        vm.mockCall(address(p.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
        p.acceptTaskResults(taskIds, "", abi.encode(report));

        // Now expect that the token cannot be bridged back by NFT_OWNER_10

        BridgeEndpoint.TokenDescriptor memory unknownDesc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: 1,
            holder: NFT_OWNER_10
        });
        taskIds[0] = p.getTaskId(unknownDesc);
        report[0] = unknownDesc;
        vm.mockCall(address(p.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        p.acceptTaskResults(taskIds, "", abi.encode(report));
    }
}
