// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {ITaskAcceptorV1, TaskIdSelectorOps} from "escrin/tasks/acceptor/TaskAcceptor.sol";
import {IERC721, ERC721} from "openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Abutment} from "../src/Abutment.sol";

contract MockNFT is ERC721 {
    uint256 private nextTokenId;

    constructor() ERC721("TestToken", "TEST") {
        return;
    }

    function test() public pure {
        return;
    }

    function mint(address _to) external returns (uint256 id) {
        nextTokenId++;
        _mint(_to, nextTokenId);
        return nextTokenId;
    }
}

contract MockAbutment is Abutment {
    mapping(IERC721 => bool) private support;

    constructor()
        Abutment(
            Abutment.AbutmentConfig({taskAcceptorUpdateDelay: 7 days, initialTaskAcceptor: address(42)})
        )
    {
        return;
    }

    function setSupport(IERC721 _token, bool _support) external {
        if (_support) _addCollectionSupport(_token);
        else _removeCollectionSupport(_token);
    }

    function _onBallotApproved(IERC721 _token) internal override {
        _addCollectionSupport(_token);
    }
}

contract AbutmentTest is Test {
    using TaskIdSelectorOps for ITaskAcceptorV1.TaskIdSelector;

    MockAbutment private ep;
    MockNFT private nft;

    function setUp() public {
        ep = new MockAbutment();
        nft = new MockNFT();
        ep.setSupport(nft, true);
        vm.mockCall(address(ep.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
    }

    function testSendUnsupportedToken() public {
        ep.setSupport(nft, false);
        uint256 myTokenId = nft.mint(address(this));
        vm.expectRevert(Abutment.UnsupportedToken.selector);
        nft.safeTransferFrom(address(this), address(ep), myTokenId);
    }

    // function testAddCollection() public {
    //     // Ensure that only the portal owner can propose tokens.
    //     vm.prank(address(999));
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     p.proposeToken(address(nft), address(888));

    //     // Ensure that only ERC721Enumerable are acceptable.
    //     ERC721 unsupportedNft = new UnsupportedNonEnumerableNFT();
    //     vm.expectRevert(Abutment.UnsupportedToken.selector);
    //     p.proposeToken(address(unsupportedNft), address(888));

    //     // Ensure that only reasonable NFTs are acceptable.
    //     ERC721 unreasonableNft = new UnsupportedUnreasonableNFT();
    //     vm.expectRevert("invalid request");
    //     p.proposeToken(address(unreasonableNft), address(888));

    //     p.proposeToken(address(nft), address(888));
    //     // vm.expectEmit();
    //     // emit Portal.TokenProposed(address(nft));
    //     (uint256 votes, uint256 quorum) = p.getVoteStatus(address(nft));
    //     address remote = p.getRemote(address(nft));
    //     require(votes == 0 && quorum == 6 && remote == address(888), "proposal failed");
    //     // TODO

    //     vm.expectRevert("already exists");
    //     p.proposeToken(address(nft), address(888));
    // }

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

        ep.acceptTaskResults(_makeTaskIds(report.length), "", abi.encode(report));

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

        ep.acceptTaskResults(_makeTaskIds(report.length), "", abi.encode(report));

        require(_getPresence(nft, myTokenId) == Abutment.Presence.Wallet, "presence not wallet");
        assertEq(nft.ownerOf(myTokenId), address(this));

        // And now we bridge back.

        // But first the token needs to be held by the endpoint. We expect idempotence in any case.
        ep.acceptTaskResults(_makeTaskIds(report.length), "", abi.encode(report));
        require(_getPresence(nft, myTokenId) == Abutment.Presence.Wallet, "presence not wallet");

        nft.safeTransferFrom(address(this), address(ep), myTokenId);
        require(_getPresence(nft, myTokenId) == Abutment.Presence.Abutment, "presence not ep");
        report[0] = Abutment.BridgeAction({
            token: nft,
            tokenId: myTokenId,
            effect: Abutment.ActionEffect.Lock,
            recipient: address(0)
        });
        ep.acceptTaskResults(_makeTaskIds(report.length), "", abi.encode(report));
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

        ep.acceptTaskResults(_makeTaskIds(report.length), "", abi.encode(report));

        require(_getPresence(nft, tokenIdComing) == Abutment.Presence.Wallet, "presence not wallet");
        assertEq(nft.ownerOf(tokenIdComing), address(this));

        require(_getPresence(nft, tokenIdGoing) == Abutment.Presence.Absent, "presence not absent");
    }

    function _getPresence(IERC721 _token, uint256 _id) internal view returns (Abutment.Presence) {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = _id;
        Abutment.Token[] memory tokens = ep.getTokenStatuses(_token, tokenIds);
        return tokens[0].presence;
    }

    function _makeTaskIds(uint256 count) internal pure returns (uint256[] memory) {
        uint256[] memory ids = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            ids[i] = i;
        }
        return ids;
    }
}
