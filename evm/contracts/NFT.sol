// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {TaskAcceptorV1, TaskIdSelectorOps} from "@escrin/evm/contracts/tasks/acceptor/TaskAcceptor.sol";
import {DelegatedTaskAcceptorV1} from "@escrin/evm/contracts/tasks/acceptor/DelegatedTaskAcceptor.sol";
import {TaskHubV1Notifier} from "@escrin/evm/contracts/tasks/widgets/TaskHubNotifier.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {ERC721AQueryable} from "erc721a/contracts/extensions/ERC721AQueryable.sol";

contract AIRose is ERC721A, ERC721AQueryable {
    constructor() ERC721A("AI Rose", "AIROSE") {}
}
