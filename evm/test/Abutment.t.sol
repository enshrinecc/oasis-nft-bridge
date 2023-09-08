// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {InterfaceUnsupported} from "escrin/Types.sol";
import {IdentityId, IIdentityRegistry} from "escrin/identity/v1/IdentityRegistry.sol";
import {ITaskAcceptor, TaskIdSelectorOps} from "escrin/tasks/v1/acceptors/TaskAcceptor.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC721} from "openzeppelin/contracts/token/ERC721/IERC721.sol";

import {Abutment} from "../src/Abutment.sol";
import {MockIdentityRegistry, MockNFT, makeTaskIds} from "./Shared.sol";

contract MockAbutment is Abutment {
    constructor(TrustedIdentity memory identity)
        Abutment(AbutmentConfig({trustedIdentityUpdateDelay: 7 days, identity: identity}))
    {}

    function addCollection(IERC721 token, address remote, uint256 supply) external {
        _addCollection(token, remote, supply);
    }

    function setSupport(IERC721 token, bool support) external {
        if (support) _addCollectionSupport(token);
        else _removeCollectionSupport(token);
    }

    function _onBallotApproved(IERC721 token) internal override {
        _addCollectionSupport(token);
    }
}

contract AbutmentTest is Test {
    using TaskIdSelectorOps for ITaskAcceptor.TaskIdSelector;

    MockAbutment private ep;
    MockNFT private nft;
    MockNFT private newNft;
    IIdentityRegistry private reg;

    function setUp() public {
        reg = new MockIdentityRegistry();
        IdentityId iid = IdentityId.wrap(1234);
        ep = new MockAbutment(Abutment.TrustedIdentity({
            registry: reg,
            id: iid
        }));
        newNft = new MockNFT();
        nft = new MockNFT();
        ep.setSupport(nft, true);
        vm.mockCall(
            address(reg),
            abi.encodeWithSelector(IIdentityRegistry.readPermit.selector, address(this), iid),
            abi.encode(IIdentityRegistry.Permit({expiry: type(uint64).max}))
        );
    }

    function testSendUnsupportedToken() public {
        uint256 myTokenId = newNft.mint(address(this));
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        newNft.safeTransferFrom(address(this), address(ep), myTokenId);
    }

    function testVote() public {
        address a = address(0x678);
        address b = address(0x789);
        uint256[] memory tokenIdsA1 = new uint256[](2);
        uint256[] memory tokenIdsA2 = new uint256[](4);
        uint256[] memory tokenIdsB = new uint256[](1);

        tokenIdsA2[0] = newNft.mint(a);
        tokenIdsA2[1] = newNft.mint(a);
        tokenIdsA2[2] = newNft.mint(a);
        tokenIdsA1[0] = tokenIdsA2[0];
        tokenIdsA1[1] = tokenIdsA2[1];

        tokenIdsB[0] = newNft.mint(b);
        tokenIdsA2[3] = newNft.mint(b); // This is intentional to ensure ownership is checked
        newNft.mint(b);

        // Ensure voting on unsupported token fails.
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        ep.vote(newNft, tokenIdsA1);
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        ep.getRemote(newNft);
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        ep.getVoteStatus(newNft);
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        ep.getVotingTokens(a, newNft);

        // Register NFT
        address remote = address(0x5afe);
        uint256 supply = 6;
        ep.addCollection(newNft, remote, supply);
        require(ep.getRemote(newNft) == remote);

        // Test voting ability
        uint256[] memory aVotingTokens = ep.getVotingTokens(a, newNft);
        assertEq(aVotingTokens.length, 3);
        assertEq(aVotingTokens[0], 1);
        assertEq(aVotingTokens[1], 2);
        assertEq(aVotingTokens[2], 3);
        uint256[] memory bVotingTokens = ep.getVotingTokens(b, newNft);
        assertEq(bVotingTokens.length, 3);
        assertEq(bVotingTokens[0], 4);
        assertEq(bVotingTokens[1], 5);
        assertEq(bVotingTokens[2], 6);

        // Test voting
        vm.prank(a);
        ep.vote(newNft, tokenIdsA1);
        (uint256 approvals, uint256 quorum) = ep.getVoteStatus(newNft);
        require(quorum == 6 / 2 + 1, "wrong quorum");
        require(approvals == 2, "wrong approvals");
        aVotingTokens = ep.getVotingTokens(a, newNft);
        assertEq(aVotingTokens.length, 1);
        assertEq(aVotingTokens[0], 3);

        vm.prank(a);
        ep.vote(newNft, tokenIdsA2);
        (approvals,) = ep.getVoteStatus(newNft);
        require(approvals == 3, "wrong approvals"); // the first two votes were already counted and one belongs to b
        aVotingTokens = ep.getVotingTokens(a, newNft);
        assertEq(aVotingTokens.length, 0);

        require(ep.getSupportedCollections().length == 1, "newNft wrongly supported");

        vm.prank(b);
        ep.vote(newNft, tokenIdsB);
        (approvals,) = ep.getVoteStatus(newNft);
        require(approvals == 4, "wrong approvals");

        require(ep.getSupportedCollections().length == 2, "newNft wrongly unsupported");
    }

    function testUpdateTrustedIdentity() public {
        vm.prank(address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0))
        );
        ep.setTrustedIdentity(
            Abutment.TrustedIdentity({
                registry: IIdentityRegistry(address(0)),
                id: IdentityId.wrap(0)
            })
        );

        vm.expectRevert(InterfaceUnsupported.selector);
        ep.setTrustedIdentity(
            Abutment.TrustedIdentity({
                registry: IIdentityRegistry(address(0)),
                id: IdentityId.wrap(0)
            })
        );

        ep.setTrustedIdentity(Abutment.TrustedIdentity({registry: reg, id: IdentityId.wrap(4321)}));
        (IIdentityRegistry trustedRegistry, IdentityId trustedIdentity) = ep.getTrustedIdentity();
        assertEq(address(trustedRegistry), address(reg));
        assertEq(IdentityId.unwrap(trustedIdentity), 1234);
        assertEq(ep.incomingTrustedIdentityActiveTime(), block.timestamp + 7 days);

        vm.expectRevert(Abutment.TooSoon.selector);
        ep.setTrustedIdentity(Abutment.TrustedIdentity({registry: reg, id: IdentityId.wrap(4321)}));

        vm.warp(block.timestamp + 7 days);
        ep.setTrustedIdentity(Abutment.TrustedIdentity({registry: reg, id: IdentityId.wrap(4321)}));
        (trustedRegistry, trustedIdentity) = ep.getTrustedIdentity();
        assertEq(address(trustedRegistry), address(reg));
        assertEq(IdentityId.unwrap(trustedIdentity), 4321);
    }

    function testBridgeOneOutAndIn() public {
        uint256 myTokenId = nft.mint(address(this));

        Abutment.BridgeAction memory action = Abutment.BridgeAction({
            token: IERC721(nft),
            tokenId: myTokenId,
            effect: Abutment.ActionEffect.Lock,
            recipient: address(0)
        });
        Abutment.BridgeAction[] memory report = new Abutment.BridgeAction[](1);
        report[0] = action;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = action.tokenId;
        Abutment.Token[] memory tokens = ep.getTokenStatuses(action.token, tokenIds);
        require(tokens[0].presence == Abutment.Presence.Unknown, "presence not unk");
        require(tokens[1].presence == Abutment.Presence.Unknown, "presence not unk");

        nft.safeTransferFrom(address(this), address(ep), myTokenId);

        tokens = ep.getTokenStatuses(action.token, tokenIds);
        require(tokens[0].presence == Abutment.Presence.Abutment, "presence not ep");
        require(tokens[1].presence == Abutment.Presence.Unknown, "presence not unk");

        vm.prank(address(0));
        require(
            ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report)).quantifier
                == ITaskAcceptor.Quantifier.None,
            "task results wrongly accepted"
        );
        require(
            ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report)).quantifier
                == ITaskAcceptor.Quantifier.All,
            "task results not accepted"
        );

        tokens = ep.getTokenStatuses(action.token, tokenIds);
        require(tokens[0].presence == Abutment.Presence.Absent, "presence not absent");
        require(tokens[1].presence == Abutment.Presence.Unknown, "presence not unk");
    }

    function testBridgeOneInAndOut() public {
        uint256 myTokenId = nft.mint(address(ep));

        Abutment.BridgeAction[] memory report = new Abutment.BridgeAction[](1);
        report[0] = Abutment.BridgeAction({
            token: nft,
            tokenId: myTokenId,
            effect: Abutment.ActionEffect.Release,
            recipient: address(this)
        });

        require(_getPresence(nft, myTokenId) == Abutment.Presence.Unknown, "presence not unk");

        vm.prank(address(0));
        require(
            ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report)).quantifier
                == ITaskAcceptor.Quantifier.None,
            "task results wrongly accepted"
        );
        require(
            ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report)).quantifier
                == ITaskAcceptor.Quantifier.All,
            "task results not accepted"
        );

        require(_getPresence(nft, myTokenId) == Abutment.Presence.Wallet, "presence not wallet");
        assertEq(nft.ownerOf(myTokenId), address(this));

        // And now we bridge back.

        // But first the token needs to be held by the endpoint. We expect idempotence in any case.
        ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report));
        require(_getPresence(nft, myTokenId) == Abutment.Presence.Wallet, "presence not wallet");

        nft.safeTransferFrom(address(this), address(ep), myTokenId);
        require(_getPresence(nft, myTokenId) == Abutment.Presence.Abutment, "presence not ep");
        report[0] = Abutment.BridgeAction({
            token: nft,
            tokenId: myTokenId,
            effect: Abutment.ActionEffect.Lock,
            recipient: address(0)
        });
        ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report));
        require(_getPresence(nft, myTokenId) == Abutment.Presence.Absent, "presence not absent");
    }

    function testBridgeMultiple() public {
        uint256 tokenIdGoing = nft.mint(address(this));
        uint256 tokenIdComing = nft.mint(address(ep));

        Abutment.BridgeAction memory actionComing = Abutment.BridgeAction({
            token: nft,
            tokenId: tokenIdComing,
            effect: Abutment.ActionEffect.Release,
            recipient: address(this)
        });
        Abutment.BridgeAction memory actionGoing = Abutment.BridgeAction({
            token: nft,
            tokenId: tokenIdGoing,
            effect: Abutment.ActionEffect.Lock,
            recipient: address(0)
        });

        Abutment.BridgeAction[] memory report = new Abutment.BridgeAction[](2);
        (report[0], report[1]) = (actionComing, actionGoing);

        nft.safeTransferFrom(address(this), address(ep), tokenIdGoing);

        ep.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report));

        require(_getPresence(nft, tokenIdComing) == Abutment.Presence.Wallet, "presence not wallet");
        assertEq(nft.ownerOf(tokenIdComing), address(this));

        require(_getPresence(nft, tokenIdGoing) == Abutment.Presence.Absent, "presence not absent");
    }

    function _getPresence(IERC721 token, uint256 id) internal view returns (Abutment.Presence) {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = id;
        Abutment.Token[] memory tokens = ep.getTokenStatuses(token, tokenIds);
        return tokens[0].presence;
    }
}
