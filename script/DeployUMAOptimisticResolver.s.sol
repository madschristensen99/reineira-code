// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {UMAOptimisticResolver} from "../contracts/resolvers/UMAOptimisticResolver.sol";

contract DeployUMAOptimisticResolver is Script {
    function run() external returns (UMAOptimisticResolver) {
        vm.startBroadcast();
        
        UMAOptimisticResolver resolver = new UMAOptimisticResolver();
        
        vm.stopBroadcast();
        
        return resolver;
    }
}
