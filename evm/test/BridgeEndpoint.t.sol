// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";

import {ITaskAcceptorV1, TaskIdSelectorOps} from "@escrin/evm/contracts/tasks/acceptor/TaskAcceptor.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {BridgeEndpoint} from "../contracts/BridgeEndpoint.sol";

contract MockNFT is ERC721 {
    uint256 private nextTokenId;

    constructor() ERC721("TestToken", "TEST") {
        return;
    }

    function mint(address to) external returns (uint256 id) {
        nextTokenId++;
        _mint(to, nextTokenId);
        return nextTokenId;
    }
}

contract MockBridgeEndpoint is BridgeEndpoint {
    mapping(address => bool) private support;

    constructor()
        BridgeEndpoint(
            BridgeEndpoint.Config({
                bridgingTimeout: 10 minutes,
                taskAcceptorUpdateDelay: 7 days,
                initialTaskAcceptor: address(42)
            })
        )
    {
        return;
    }

    function setSupport(address _token, bool _support) external {
        support[_token] = _support;
    }

    function _tokenIsSupported(address _token) internal view override returns (bool) {
        return support[_token];
    }
}

contract BridgeEndpointTest is Test {
    using TaskIdSelectorOps for ITaskAcceptorV1.TaskIdSelector;

    MockBridgeEndpoint private ep;
    MockNFT private nft;

    function setUp() public {
        ep = new MockBridgeEndpoint();
        nft = new MockNFT();
        ep.setSupport(address(nft), true);
    }

    function testSendUnsupportedToken() public {
        ep.setSupport(address(nft), false);
        uint256 myNft = nft.mint(address(this));
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        nft.safeTransferFrom(address(this), address(ep), myNft);
    }

    function testReclaim() public {
        uint256 myNft = nft.mint(address(this));
        nft.safeTransferFrom(address(this), address(ep), myNft);

        // Cannot reclaim before the bridging timeout.
        vm.expectRevert(BridgeEndpoint.TooSoon.selector);
        ep.reclaimToken(
            BridgeEndpoint.TokenDescriptor({token: address(nft), id: myNft, holder: address(this)})
        );

        // Can reclaim after the bridging timeout.
        vm.warp(block.timestamp + ep.bridgingTimeout());
        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: myNft,
            holder: address(this)
        });
        // vm.expectEmit();
        // emit BridgeEndpoint.TokenReclaimed(desc.token, desc.id, desc.holder);
        ep.reclaimToken(desc);
        require(nft.ownerOf(myNft) == address(this), "reclaim failed");

        // Already reclaimed.
        vm.expectRevert();
        ep.reclaimToken(desc);
    }

    function testBridgeTo() public {
        uint256 myNft = nft.mint(address(this));
        nft.safeTransferFrom(address(this), address(ep), myNft);

        vm.mockCall(address(ep.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: myNft,
            holder: address(this)
        });
        uint256[] memory taskIds = new uint256[](1);
        taskIds[0] = ep.getTaskId(desc);
        // vm.expectEmit();
        // emit BridgeEndpoint.BridgingRequested(desc.token, desc.id, desc.holder);
        ep.acceptTaskResults(taskIds, "", "");

        // Cannot reclaim after bridging.
        vm.warp(block.timestamp + ep.bridgingTimeout());
        vm.expectRevert(BridgeEndpoint.NotPresent.selector);
        ep.reclaimToken(desc);

        // Bridge back.
        ep.acceptTaskResults(taskIds, "", "");
        ep.reclaimToken(desc);
        require(nft.ownerOf(myNft) == address(this), "reclaim failed");
    }

    function testBridgeFrom() public {
        uint256 myNft = nft.mint(address(ep));

        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: myNft,
            holder: address(this)
        });

        // Cannot reclaim yet.
        vm.expectRevert(BridgeEndpoint.NotPresent.selector);
        ep.reclaimToken(desc);

        vm.mockCall(address(ep.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
        uint256[] memory taskIds = new uint256[](1);
        taskIds[0] = ep.getTaskId(desc);
        // vm.expectEmit();
        // emit BridgeEndpoint.BridgingRequested(desc.token, desc.id, desc.holder);
        ep.acceptTaskResults(taskIds, "", "");

        ep.reclaimToken(desc);
        require(nft.ownerOf(desc.id) == address(this), "reclaim failed");

        // Bridge back.
        ep.acceptTaskResults(taskIds, "", "");
        vm.expectRevert(BridgeEndpoint.NotPresent.selector);
        ep.reclaimToken(desc);
    }
}
