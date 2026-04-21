// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/// @title ReclaimResolver
/// @notice zkTLS-based condition resolver using Reclaim Protocol
/// @dev Releases escrow when valid proof of HTTPS endpoint data is submitted
contract ReclaimResolver is IConditionResolver, ERC165 {
    struct Config {
        address verifier;
        bytes32 expectedClaimHash;
        bool fulfilled;
    }

    mapping(uint256 => Config) public configs;
    mapping(bytes32 => bool) public usedProofs;

    event ConditionSet(uint256 indexed escrowId, address verifier, bytes32 expectedClaimHash);
    event ProofSubmitted(uint256 indexed escrowId, bytes32 proofHash);

    error InvalidVerifier();
    error InvalidClaimHash();
    error ConditionAlreadySet();
    error AlreadyFulfilled();
    error ProofAlreadyUsed();
    error InvalidProof();

    /// @inheritdoc IConditionResolver
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        if (configs[escrowId].verifier != address(0)) revert ConditionAlreadySet();

        (address verifier, bytes32 expectedClaimHash) = abi.decode(data, (address, bytes32));
        
        if (verifier == address(0)) revert InvalidVerifier();
        if (expectedClaimHash == bytes32(0)) revert InvalidClaimHash();

        configs[escrowId] = Config({
            verifier: verifier,
            expectedClaimHash: expectedClaimHash,
            fulfilled: false
        });

        emit ConditionSet(escrowId, verifier, expectedClaimHash);
    }

    /// @notice Submit a zkTLS proof to fulfill the condition
    /// @param escrowId The escrow identifier
    /// @param proof The Reclaim proof data
    function submitProof(uint256 escrowId, bytes calldata proof) external {
        Config storage config = configs[escrowId];
        
        if (config.fulfilled) revert AlreadyFulfilled();

        bytes32 proofHash = keccak256(proof);
        if (usedProofs[proofHash]) revert ProofAlreadyUsed();

        if (!_verifyProof(config.verifier, proof, config.expectedClaimHash)) {
            revert InvalidProof();
        }

        usedProofs[proofHash] = true;
        config.fulfilled = true;

        emit ProofSubmitted(escrowId, proofHash);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        return configs[escrowId].fulfilled;
    }

    /// @dev Internal proof verification logic
    /// @param verifier The Reclaim verifier contract address
    /// @param proof The proof data
    /// @param expectedClaimHash The expected claim hash
    /// @return True if proof is valid
    function _verifyProof(
        address verifier,
        bytes calldata proof,
        bytes32 expectedClaimHash
    ) internal view returns (bool) {
        (bool success, bytes memory result) = verifier.staticcall(
            abi.encodeWithSignature("verifyProof(bytes,bytes32)", proof, expectedClaimHash)
        );
        
        if (!success || result.length == 0) return false;
        return abi.decode(result, (bool));
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
