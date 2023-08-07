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

    function test() public pure {
        return;
    }

    function mint(address _to) external returns (uint256 id) {
        nextTokenId++;
        _mint(_to, nextTokenId);
        return nextTokenId;
    }
}

contract MockBridgeEndpoint is BridgeEndpoint {
    mapping(address => bool) private support;

    constructor()
        BridgeEndpoint(
            BridgeEndpoint.EndpointConfig({
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

    function _tokenIsSupported(TokenDescriptor memory _desc) internal view override returns (bool) {
        return support[_desc.token];
    }

    function _getHeldTokens(
        address _token,
        uint256,
        uint256
    ) internal view override returns (uint256[] memory) {
        if (!support[_token]) return new uint256[](0);
        uint256[] memory tokens = new uint256[](3);
        tokens[0] = 1;
        tokens[1] = 2;
        tokens[2] = 3;
        return tokens;
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
        vm.mockCall(address(ep.getTaskAcceptor()), bytes(""), abi.encode(TaskIdSelectorOps.all()));
    }

    function testSendUnsupportedToken() public {
        ep.setSupport(address(nft), false);
        uint256 myNft = nft.mint(address(this));
        vm.expectRevert(BridgeEndpoint.UnsupportedToken.selector);
        nft.safeTransferFrom(address(this), address(ep), myNft);
    }

    function testBridgeOneGoing() public {
        uint256 myNft = nft.mint(address(this));

        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: myNft,
            holder: address(this)
        });
        uint256[] memory taskIds = new uint256[](1);
        BridgeEndpoint.TokenDescriptor[] memory report = new BridgeEndpoint.TokenDescriptor[](1);
        taskIds[0] = ep.getTaskId(desc);
        report[0] = desc;

        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Unknown,
            "presence not unnk"
        );

        nft.safeTransferFrom(address(this), address(ep), myNft);

        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Endpoint,
            "presence not ep"
        );

        ep.acceptTaskResults(taskIds, "", abi.encode(report));

        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Absent,
            "presence not absent"
        );
    }

    function testBridgeOneComing() public {
        uint256 myNft = nft.mint(address(ep));

        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: myNft,
            holder: address(this)
        });
        uint256[] memory taskIds = new uint256[](1);
        BridgeEndpoint.TokenDescriptor[] memory report = new BridgeEndpoint.TokenDescriptor[](1);
        taskIds[0] = ep.getTaskId(desc);
        report[0] = desc;

        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Unknown,
            "presence not unk"
        );

        ep.acceptTaskResults(taskIds, "", abi.encode(report));

        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Wallet,
            "presence not wallet"
        );
        assertEq(nft.ownerOf(desc.id), desc.holder);

        // And now we bridge back.

        // But first the token needs to be held by the endpoint.
        vm.expectRevert(BridgeEndpoint.NotPresent.selector);
        ep.acceptTaskResults(taskIds, "", abi.encode(report));

        nft.safeTransferFrom(address(this), address(ep), myNft);
        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Endpoint,
            "presence not ep"
        );
        ep.acceptTaskResults(taskIds, "", abi.encode(report));
        require(
            ep.getTokenPresence(desc) == BridgeEndpoint.TokenPresence.Absent,
            "presence not absent"
        );
    }

    function testBridgeMultiple() public {
        uint256 nftGoing = nft.mint(address(this));
        uint256 nftComing = nft.mint(address(ep));

        BridgeEndpoint.TokenDescriptor memory descComing = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: nftComing,
            holder: address(this)
        });
        BridgeEndpoint.TokenDescriptor memory descGoing = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: nftGoing,
            holder: address(this)
        });
        uint256 taskIdComing = ep.getTaskId(descComing);
        uint256 taskIdGoing = ep.getTaskId(descGoing);

        uint256[] memory taskIds = new uint256[](2);
        BridgeEndpoint.TokenDescriptor[] memory report = new BridgeEndpoint.TokenDescriptor[](2);

        if (taskIdComing < taskIdGoing) {
            (taskIds[0], report[0]) = (taskIdComing, descComing);
            (taskIds[1], report[1]) = (taskIdGoing, descGoing);
        } else {
            (taskIds[0], report[0]) = (taskIdGoing, descGoing);
            (taskIds[1], report[1]) = (taskIdComing, descComing);
        }

        nft.safeTransferFrom(address(this), address(ep), nftGoing);

        ep.acceptTaskResults(taskIds, "", abi.encode(report));

        require(
            ep.getTokenPresence(descComing) == BridgeEndpoint.TokenPresence.Wallet,
            "presence not wallet"
        );
        assertEq(nft.ownerOf(descComing.id), descComing.holder);

        require(
            ep.getTokenPresence(descGoing) == BridgeEndpoint.TokenPresence.Absent,
            "presence not absent"
        );
    }

    function testMismatchedTaskId() public {
        BridgeEndpoint.TokenDescriptor memory desc = BridgeEndpoint.TokenDescriptor({
            token: address(nft),
            id: 1,
            holder: address(this)
        });
        uint256[] memory taskIds = new uint256[](1);
        BridgeEndpoint.TokenDescriptor[] memory report = new BridgeEndpoint.TokenDescriptor[](1);
        taskIds[0] = 0; // The task ID does not match the descriptor.
        report[0] = desc;

        vm.expectRevert(BridgeEndpoint.MismatchedTask.selector);
        ep.acceptTaskResults(taskIds, "", abi.encode(report));
    }
}
