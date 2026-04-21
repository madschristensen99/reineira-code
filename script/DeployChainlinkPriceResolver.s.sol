// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ChainlinkPriceResolver} from "../contracts/resolvers/ChainlinkPriceResolver.sol";

contract DeployChainlinkPriceResolver is Script {
    function run() external returns (ChainlinkPriceResolver) {
        vm.startBroadcast();
        
        ChainlinkPriceResolver resolver = new ChainlinkPriceResolver();
        
        vm.stopBroadcast();
        
        return resolver;
    }
}
