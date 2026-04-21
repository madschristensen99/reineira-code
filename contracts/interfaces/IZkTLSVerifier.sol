// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IZkTLSVerifier
/// @notice Interface for zkTLS proof verification systems.
/// @dev Implement this to verify zero-knowledge proofs of TLS session data.
///      Used by condition resolvers that require authenticated off-chain data
///      (e.g., proving a specific HTTP response was received from a server).
///
/// ## Security & Privacy Considerations
///
/// **Adapter Boundary (P8):**
/// Adapters implementing this interface are the weakest privacy link. Rules:
/// 1. Plaintext score/data lives for ONE stack frame only: verify → encrypt → return
/// 2. NO events containing scores, amounts, or commitment values
/// 3. NO "what did you last return" view functions
/// 4. State needed for nonces/replay is opaque (bytes32), not (id, value) tuples
///
/// **Freshness & Replay Protection:**
/// All proof-based resolvers MUST use ProofGuard.consume() to prevent proof reuse
/// across escrows. Timestamp validation prevents stale data attacks.
///
/// **Access Control:**
/// Only registered resolver contracts should call verifyProof. Consider gating
/// with an allowlist to prevent arbitrary proof queries that could leak metadata.
interface IZkTLSVerifier {
    /// @notice Verify a zkTLS proof against expected parameters.
    /// @dev MUST be a view function. Implementations should validate:
    ///      - Proof cryptographic validity
    ///      - Server identity (domain/certificate)
    ///      - Data commitment matches expected value
    ///      - Timestamp is within acceptable range
    /// @param proof The zkTLS proof data (format is verifier-specific).
    /// @param publicInputs Public inputs for verification (e.g., domain, commitment).
    /// @return valid True if the proof is valid and matches public inputs.
    function verifyProof(bytes calldata proof, bytes calldata publicInputs) external view returns (bool valid);

    /// @notice Extract the timestamp from a zkTLS proof.
    /// @dev Used for freshness validation. MUST be a view function.
    /// @param proof The zkTLS proof data.
    /// @return timestamp Unix timestamp when the TLS session occurred.
    function extractTimestamp(bytes calldata proof) external view returns (uint256 timestamp);

    /// @notice Extract the data commitment from a zkTLS proof.
    /// @dev The commitment is typically a hash of the attested data.
    /// @param proof The zkTLS proof data.
    /// @return commitment The data commitment (e.g., keccak256 of response body).
    function extractCommitment(bytes calldata proof) external pure returns (bytes32 commitment);
}
