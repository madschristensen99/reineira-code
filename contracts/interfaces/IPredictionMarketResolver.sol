// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "./IConditionResolver.sol";

/// @title IPredictionMarketResolver
/// @notice Extended interface for prediction market-based condition resolvers.
/// @dev Extends IConditionResolver with prediction market outcome resolution.
///      Supports binary and categorical markets from providers like Polymarket, UMA, etc.
///
/// ## Security & Privacy Considerations
///
/// **Settlement-Based Resolution:**
/// Prediction market resolvers depend on external market settlement. The resolver
/// must validate that outcomes are finalized before releasing escrow funds.
///
/// **Access Control (T4):**
/// getOutcomeState and related query methods should be gated to prevent:
/// - Correlation of escrows to specific prediction markets
/// - Timing-based inference of market resolution
/// - Binary-search attacks on expected outcomes
///
/// **Outcome Privacy:**
/// While market outcomes are inherently public (they're settled on-chain), the
/// mapping between escrows and specific markets should remain private. Use
/// encrypted condition IDs where possible.
///
/// **Invalid State Handling:**
/// Markets can resolve to "Invalid" if the question is ambiguous or disputed.
/// Resolvers must define clear behavior for this case (e.g., refund, split, or
/// defer to a fallback condition).
///
/// **Local Type Workarounds:**
/// External market interfaces (Polymarket CTF, UMA OOv3) are defined locally in
/// base contracts to avoid dependency management complexity. Production deployments
/// should verify these match official interfaces.
interface IPredictionMarketResolver is IConditionResolver {
    /// @notice Market outcome states.
    enum OutcomeState {
        Unresolved,
        Resolved,
        Invalid
    }

    /// @notice Get the current state of a market outcome.
    /// @dev MUST be a view function.
    /// @param escrowId The escrow identifier.
    /// @return state The current outcome state.
    /// @return winningOutcome The winning outcome index (only valid if state == Resolved).
    function getOutcomeState(uint256 escrowId) external view returns (OutcomeState state, uint256 winningOutcome);

    /// @notice Get the expected outcome for an escrow to release.
    /// @dev The condition is met when the market resolves to this outcome.
    /// @param escrowId The escrow identifier.
    /// @return expectedOutcome The outcome index that triggers release.
    function getExpectedOutcome(uint256 escrowId) external view returns (uint256 expectedOutcome);

    /// @notice Check if the market has been resolved.
    /// @dev Convenience function to check if outcome state is Resolved.
    /// @param escrowId The escrow identifier.
    /// @return True if the market has been resolved.
    function isResolved(uint256 escrowId) external view returns (bool);
}
