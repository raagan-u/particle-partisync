// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Particle} from "../src/Particle.sol";

contract DeployParticle is Script {
    function run() public {
        vm.startBroadcast();
        Particle particle = new Particle();
        particle.initialize(msg.sender);
        vm.stopBroadcast();
    }
}