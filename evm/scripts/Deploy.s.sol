// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Abutment} from "../src/Abutment.sol";
import {EmeraldAbutment} from "../src/EmeraldAbutment.sol";
import {SapphireAbutment} from "../src/SapphireAbutment.sol";

abstract contract DeploymentScript is Script {
    function _abutmentConfig() internal view returns (Abutment.AbutmentConfig memory) {
        return Abutment.AbutmentConfig({
            taskAcceptorUpdateDelay: 7 days,
            initialTaskAcceptor: address(vm.envAddress("TASK_ACCEPTOR"))
        });
    }
}

contract Emerald is DeploymentScript {
    function run() external {
        uint256 chain = block.chainid;
        require(chain == 31337 || chain == 0xa515 || chain == 0xa516, "not emerald");
        vm.broadcast();
        new EmeraldAbutment(_abutmentConfig(), 16 weeks /* token support duration */);
    }
}

contract Sapphire is DeploymentScript {
    function run() external {
        uint256 chain = block.chainid;
        require(chain == 31337 || chain == 0x5aff || chain == 0x5afe, "not sapphire");
        vm.broadcast();
        new SapphireAbutment(_abutmentConfig());
    }
}
