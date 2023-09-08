// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";

import {ERC721A, ERC721AQueryable} from "ERC721A/extensions/ERC721AQueryable.sol";
import {
    IdentityId,
    IIdentityRegistry,
    IdentityRegistry
} from "escrin/identity/v1/IdentityRegistry.sol";
import {ITaskAcceptor, TaskIdSelectorOps} from "escrin/tasks/v1/acceptors/TaskAcceptor.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC721} from "openzeppelin/contracts/token/ERC721/IERC721.sol";

import {Abutment} from "../src/Abutment.sol";
import {SapphireAbutment} from "../src/SapphireAbutment.sol";
import {makeTaskIds} from "./Shared.sol";

contract MockNFT is ERC721A, ERC721AQueryable {
    uint256 private nextTokenId;

    constructor() ERC721A("TestToken", "TEST") {}

    function test() public pure {}

    function mint(address to, uint256 quantity) external {
        _mint(to, quantity);
    }
}

contract SapphireAbutmentTest is Test {
    using TaskIdSelectorOps for ITaskAcceptor.TaskIdSelector;

    SapphireAbutment private p;
    MockNFT private nft;
    IdentityRegistry private reg;

    function setUp() public {
        reg = new IdentityRegistry();
        IdentityId iid = IdentityId.wrap(1234);
        p = new SapphireAbutment(
            Abutment.AbutmentConfig({
            owner: msg.sender,
                trustedIdentityUpdateDelay: 7 days,
                identity: Abutment.TrustedIdentity({
                    registry: reg,
                    id: iid
                })
            })
        );
        nft = new MockNFT();

        vm.mockCall(
            address(reg),
            abi.encodeWithSelector(IdentityRegistry.readPermit.selector, address(this), iid),
            abi.encode(IIdentityRegistry.Permit({expiry: type(uint64).max}))
        );
    }

    function testSupportToken() public {
        nft.mint(address(this), 11);
        p.supportToken(address(nft), address(9999));
        (, uint256 quorum) = p.getVoteStatus(IERC721(address(nft)));
        assertEq(quorum, 6);
    }

    function testTransferUnclaimed() public {
        nft.mint(address(p), 11);
        IERC721 nft_ = IERC721(address(nft));
        p.supportToken(address(nft), address(9999));

        uint256[] memory tokenIds = new uint256[](1);
        address[] memory recipients = new address[](1);
        tokenIds[0] = 0;
        recipients[0] = address(123);

        vm.expectRevert(Abutment.TooSoon.selector);
        p.transferUnclaimed(nft_, tokenIds, recipients);

        uint256[] memory votingTokens = p.getVotingTokens(address(p), nft_);
        vm.prank(address(p));
        p.vote(nft_, votingTokens);
        (uint256 votes, uint256 quorum) = p.getVoteStatus(IERC721(address(nft)));
        assertEq(votes, 11);
        assertEq(quorum, 6);

        assertEq(nft.ownerOf(0), address(p));
        p.transferUnclaimed(nft_, tokenIds, recipients);
        assertEq(nft.ownerOf(0), address(123));
    }
}
