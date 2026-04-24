// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Deploy} from "./Deploy.s.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";
import {SimpleEscrow} from "../contracts/test/SimpleEscrow.sol";
import {console2} from "forge-std/console2.sol";

/// @title DeployE2ETest
/// @notice Deploy ReclaimResolver + SimpleEscrow for end-to-end testing on Arbitrum Sepolia
contract DeployE2ETest is Deploy {
    // Reclaim verifier on Arbitrum Sepolia
    address constant RECLAIM_VERIFIER = 0x4D1ee04EB5CeE02d4C123d4b67a86bDc7cA2E62A;

    function run() public override {
        uint256 deployerPrivateKey = getDeployerPrivateKey();
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ReclaimResolver
        ReclaimResolver resolver = new ReclaimResolver();
        console2.log("ReclaimResolver deployed at:", address(resolver));

        // 2. Deploy SimpleEscrow
        SimpleEscrow escrow = new SimpleEscrow();
        console2.log("SimpleEscrow deployed at:", address(escrow));

        // 3. Create a test escrow with Reclaim condition
        bytes memory resolverConfig = abi.encode(
            RECLAIM_VERIFIER,           // Reclaim verifier address
            "http",                     // Expected provider
            "",                         // No context address validation (empty = skip)
            ""                          // No context message validation (empty = skip)
        );

        uint256 escrowId = escrow.createEscrow{value: 0.001 ether}(
            deployer,                   // Beneficiary (deployer for testing)
            address(resolver),
            resolverConfig
        );

        vm.stopBroadcast();

        // Log deployment info
        console2.log("\n=== E2E Test Deployment Complete ===");
        console2.log("Network:", getNetworkName());
        console2.log("Chain ID:", block.chainid);
        console2.log("Deployer:", deployer);
        console2.log("\nContracts:");
        console2.log("  ReclaimResolver:", address(resolver));
        console2.log("  SimpleEscrow:", address(escrow));
        console2.log("  Reclaim Verifier:", RECLAIM_VERIFIER);
        console2.log("\nTest Escrow Created:");
        console2.log("  Escrow ID:", escrowId);
        console2.log("  Amount:", 0.001 ether, "wei (0.001 ETH)");
        console2.log("  Beneficiary:", deployer);
        console2.log("\nNext Steps for E2E Test:");
        console2.log("  1. Generate a Reclaim proof using the Reclaim SDK");
        console2.log("     - Provider: 'http'");
        console2.log("     - Any HTTPS endpoint (PayPal, GitHub, etc.)");
        console2.log("  2. Submit proof:");
        console2.log("     cast send", address(resolver));
        console2.log("     'submitProof(uint256,bytes)' <escrowId> <proofData>");
        console2.log("  3. Release escrow:");
        console2.log("     cast send", address(escrow));
        console2.log("     'release(uint256)' <escrowId>");
        console2.log("  4. Check balance increased by 0.001 ETH");
        console2.log("=====================================\n");

        // Save deployments
        saveDeployment("ReclaimResolver", address(resolver));
        saveDeployment("SimpleEscrow", address(escrow));
    }
}
