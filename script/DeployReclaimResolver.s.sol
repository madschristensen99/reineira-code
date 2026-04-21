// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";

contract DeployReclaimResolver is Script {
    function run() external returns (ReclaimResolver) {
        vm.startBroadcast();
        
        ReclaimResolver resolver = new ReclaimResolver();
        
        vm.stopBroadcast();
        
        return resolver;
    }
}
