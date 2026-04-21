// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "./IConditionResolver.sol";

/// @title IOracleConditionResolver
/// @notice Extended interface for oracle-based condition resolvers.
/// @dev Extends IConditionResolver with oracle-specific functionality.
///      Implementations should support multiple oracle providers (Chainlink, UMA, etc.)
///      and handle data feed validation, staleness checks, and threshold comparisons.
///
/// ## Security & Privacy Considerations
///
/// **Staleness Checks (P2, Prova findings):**
/// Oracle-based resolvers MUST validate data freshness to prevent stale data attacks.
/// The maxStaleness parameter should be enforced in every getLatestValue call.
///
/// **Access Control (T4):**
/// isConditionMet and oracle query methods should be gated to prevent:
/// - Binary-search attacks on threshold values
/// - Correlation of escrows to specific oracle feeds
/// - Timing-based inference of condition state changes
///
/// **Threshold Privacy:**
/// While comparison operators are public (part of the condition logic), the actual
/// threshold values and oracle readings should remain encrypted where possible to
/// prevent competitors from reverse-engineering pricing models.
///
/// **Local Type Workarounds:**
/// External oracle interfaces (Chainlink, UMA) are defined locally in base contracts
/// to avoid dependency management complexity. Production deployments should verify
/// these match official interfaces.
interface IOracleConditionResolver is IConditionResolver {
    /// @notice Comparison operators for oracle value checks.
    enum ComparisonOp {
        GreaterThan,
        GreaterThanOrEqual,
        LessThan,
        LessThanOrEqual,
        Equal,
        NotEqual
    }

    /// @notice Get the latest oracle value for an escrow.
    /// @dev MUST be a view function. Returns the most recent value from the oracle feed.
    /// @param escrowId The escrow identifier.
    /// @return value The latest oracle value (scaled according to oracle decimals).
    /// @return timestamp When the value was last updated (unix seconds).
    function getLatestValue(uint256 escrowId) external view returns (int256 value, uint256 timestamp);

    /// @notice Check if the oracle data is stale.
    /// @dev Compares the last update timestamp against the configured staleness threshold.
    /// @param escrowId The escrow identifier.
    /// @return True if the data is stale and should not be trusted.
    function isStale(uint256 escrowId) external view returns (bool);

    /// @notice Get the threshold and comparison operator for an escrow.
    /// @dev Used to determine when the condition is met.
    /// @param escrowId The escrow identifier.
    /// @return threshold The target value to compare against.
    /// @return op The comparison operator to use.
    function getThreshold(uint256 escrowId) external view returns (int256 threshold, ComparisonOp op);
}
