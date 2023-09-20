// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {
    IdentityId,
    IIdentityRegistry,
    IdentityRegistry
} from "escrin/identity/v1/IdentityRegistry.sol";
import {ITaskAcceptor, TaskIdSelectorOps} from "escrin/tasks/v1/acceptors/TaskAcceptor.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {
    ERC721,
    ERC721Enumerable
} from "openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import {Abutment} from "../src/Abutment.sol";
import {EmeraldAbutment} from "../src/EmeraldAbutment.sol";
import {MockNFT, makeTaskIds} from "./Shared.sol";

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

contract EmeraldAbutmentTest is Test {
    using TaskIdSelectorOps for ITaskAcceptor.TaskIdSelector;

    address private constant NFT_OWNER_1 = address(2345);
    address private constant NFT_OWNER_10 = address(1234);
    // The quorum will be 6.

    EmeraldAbutment private p;
    MockNFT private nft;
    IdentityRegistry private reg;

    function setUp() public {
        reg = new IdentityRegistry();
        IdentityId iid = IdentityId.wrap(1234);
        p = new EmeraldAbutment(address(this), 7 days, address(reg), iid, 12 weeks);
        nft = new MockNFT();

        vm.mockCall(
            address(reg),
            abi.encodeWithSelector(IdentityRegistry.readPermit.selector, address(this), iid),
            abi.encode(IIdentityRegistry.Permit({expiry: type(uint64).max}))
        );

        nft.mint(NFT_OWNER_1);
        for (uint256 i; i < 10; ++i) {
            nft.mint(NFT_OWNER_10);
        }
    }

    function testProposeToken() public {
        // Ensure that only the portal owner can propose tokens.
        vm.prank(address(0));
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0))
        );
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

    function testBridgeComingFromWrongSender() public {
        p.proposeToken(address(nft), address(888));

        uint256[] memory votingTokens = p.getVotingTokens(NFT_OWNER_10, nft);
        vm.prank(NFT_OWNER_10);
        p.vote(nft, votingTokens);

        vm.prank(NFT_OWNER_1);
        nft.safeTransferFrom(NFT_OWNER_1, address(p), 1);

        // First send the token over the bridge by NFT_OWNER_1.

        Abutment.BridgeAction[] memory report = new Abutment.BridgeAction[](1);
        report[0] = Abutment.BridgeAction({
            token: nft,
            tokenId: 1,
            effect: Abutment.ActionEffect.Lock,
            recipient: NFT_OWNER_1
        });

        require(
            p.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report)).quantifier
                == ITaskAcceptor.Quantifier.All,
            "task results not accepted"
        );

        // Now expect that the token cannot be bridged back by NFT_OWNER_10

        report[0] = Abutment.BridgeAction({
            token: nft,
            tokenId: 1,
            effect: Abutment.ActionEffect.Release,
            recipient: NFT_OWNER_10
        });

        vm.expectRevert(Abutment.UnsupportedToken.selector);
        p.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report));

        // And it should go back to the original owner just fine.

        report[0] = Abutment.BridgeAction({
            token: nft,
            tokenId: 1,
            effect: Abutment.ActionEffect.Release,
            recipient: NFT_OWNER_1
        });

        p.acceptTaskResults(makeTaskIds(report.length), "", abi.encode(report));
    }
}
