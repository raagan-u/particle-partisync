// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {PartiSync} from "../src/PartiSync.sol";

contract DeployPartiSync is Script {
    function run() public {
        vm.startBroadcast();
        new PartiSync(0x733E0CF1fFcBdB93f456e1317Ec8306F8acea404, msg.sender);
        vm.stopBroadcast();
    }
}