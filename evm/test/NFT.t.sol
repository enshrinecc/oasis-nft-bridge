// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Test} from "forge-std/Test.sol";

import {ITaskAcceptorV1, TaskIdSelectorOps} from "@escrin/evm/contracts/tasks/acceptor/TaskAcceptor.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {BridgeEndpoint} from "../contracts/BridgeEndpoint.sol";
import {NFT} from "../contracts/NFT.sol";

uint256 constant TOTAL_SUPPLY = 9;

contract NFTTest is Test {
    using TaskIdSelectorOps for ITaskAcceptorV1.TaskIdSelector;

    NFT private nft;

    function setUp() public {
        nft = new NFT(
            NFT.NFTConfig({
                name: "AI ROSE",
                symbol: "AIROSE",
                baseURI: "/ipfs/.../",
                totalSupply: TOTAL_SUPPLY
            }),
            BridgeEndpoint.EndpointConfig({
                taskAcceptorUpdateDelay: 7 days,
                initialTaskAcceptor: address(42)
            }),
            5000
        );
    }

    function testMetadata() public {
        require(keccak256(bytes(nft.name())) == keccak256("AI ROSE"), "wrong name");
        require(keccak256(bytes(nft.symbol())) == keccak256("AIROSE"), "wrong symbol");
        require(keccak256(bytes(nft.tokenURI(1))) == keccak256("/ipfs/.../1"), "wrong base URI");
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        nft.tokenURI(0);
        require(nft.totalSupply() == TOTAL_SUPPLY, "wrong supply");
    }

    function testSendUnsupportedToken() public {
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        nft.onERC721Received(msg.sender, address(this), 1, "");
    }

    function testVoteToFreezeBridge() public {
        vm.prank(address(nft));
        nft.setApprovalForAll(address(this), true);

        address owner1 = address(1001);
        address owner2 = address(1002);
        address owner3 = address(1003);

        vm.startPrank(address(nft));
        nft.transferFrom(address(nft), owner1, 1);
        nft.transferFrom(address(nft), owner1, 2);
        nft.transferFrom(address(nft), owner2, 3);
        nft.transferFrom(address(nft), owner2, 4);
        nft.transferFrom(address(nft), owner2, 5);
        vm.stopPrank();

        uint256[] memory unclaimed = new uint256[](1);
        address[] memory unclaimedRecipients = new address[](1);
        unclaimed[0] = 6;
        unclaimedRecipients[0] = owner3;
        vm.expectRevert(NFT.TooSoon.selector);
        nft.transferUnclaimed(unclaimed, unclaimedRecipients);

        // First owner 1 votes with their entire weight.
        // Also ensure that voice only works when the caller owns the tokens.
        uint256[] memory voice1 = _makeVoice(1, 2, 3);
        vm.prank(owner1);
        nft.voteToFreezeBridge(voice1);
        require(nft.votesToFreeze() == 2, "vote1 failed");
        require(!nft.frozen(), "froze early");

        // Next owner 1 will transfer their stake to owner 2, but the tokens have already voted, so they don't count for extra.
        vm.startPrank(owner1);
        nft.safeTransferFrom(owner1, owner2, 1);
        nft.safeTransferFrom(owner1, owner2, 2);
        vm.stopPrank();

        // Ensure that the old owner1's tokens don't vote.
        uint256[] memory voice2 = _makeVoice(1, 2, 3);
        vm.prank(owner2);
        nft.voteToFreezeBridge(voice2);
        require(nft.votesToFreeze() == 3, "vote2 failed");
        require(!nft.frozen(), "froze early");

        // Ensure that the remaining two tokens vote and cause a freeze.
        uint256[] memory voice2r = _makeVoice(4, 4, 5);
        vm.prank(owner2);
        nft.voteToFreezeBridge(voice2r);
        require(nft.votesToFreeze() == 5, "vote2r failed");
        require(nft.frozen(), "froze late");

        // Now that the bridge is frozen, unclaimed tokens can be transferred away by the owner.
        vm.prank(owner3);
        vm.expectRevert("Ownable: caller is not the owner");
        nft.transferUnclaimed(unclaimed, unclaimedRecipients);

        vm.expectRevert("length mismatch");
        nft.transferUnclaimed(unclaimed, new address[](0));
        vm.expectRevert("length mismatch");
        nft.transferUnclaimed(new uint256[](0), unclaimedRecipients);

        nft.transferUnclaimed(unclaimed, unclaimedRecipients);
        require(nft.ownerOf(unclaimed[0]) == unclaimedRecipients[0], "reclaim failed");

        // And once the bridge is frozen, tokens cannot be accepted for sending.
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        vm.prank(owner3);
        nft.safeTransferFrom(owner3, address(nft), unclaimed[0]);
    }

    function _makeVoice(
        uint256 v1,
        uint256 v2,
        uint256 v3
    ) internal pure returns (uint256[] memory) {
        uint256 count = (v1 != 0 ? 1 : 0) + (v2 != 0 ? 1 : 0) + (v3 != 0 ? 1 : 0);
        uint256[] memory voice = new uint256[](count);
        if (v1 != 0) voice[0] = v1;
        if (v2 != 0) voice[1] = v2;
        if (v3 != 0) voice[2] = v3;
        return voice;
    }

    function testOnlyBridgerInCanBridgeOut() public {
        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: 1,
            holder: address(this)
        });
        uint256[] memory taskIds = new uint256[](1);
        BridgeEndpoint.TokenDescriptor[] memory report = new BridgeEndpoint.TokenDescriptor[](1);
        taskIds[0] = nft.getTaskId(desc);
        report[0] = desc;
        vm.mockCall(address(nft.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
        nft.acceptTaskResults(taskIds, "", abi.encode(report));

        nft.transferFrom(address(this), address(1001), 1);
        vm.prank(address(1001));
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        nft.safeTransferFrom(address(1001), address(nft), 1);

        vm.prank(address(1001));
        nft.transferFrom(address(1001), address(this), 1);
        nft.safeTransferFrom(address(this), address(nft), 1);
    }
}
