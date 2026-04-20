// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IOptimisticOracleV3 {
    function settleAndGetPrice(bytes32 assertionId) external returns (int256);
    function getAssertion(bytes32 assertionId) external view returns (bool settled, int256 price);
}

/// @title UMAOptimisticResolver
/// @notice Prediction market resolver using UMA Optimistic Oracle V3
/// @dev Releases escrow when assertion settles with expected outcome
contract UMAOptimisticResolver is IConditionResolver, ERC165 {
    struct Config {
        address oracle;
        bytes32 assertionId;
        int256 expectedOutcome;
        bool settled;
    }

    mapping(uint256 => Config) public configs;

    event ConditionSet(uint256 indexed escrowId, address oracle, bytes32 assertionId, int256 expectedOutcome);
    event AssertionSettled(uint256 indexed escrowId, int256 outcome);

    error InvalidOracle();
    error InvalidAssertionId();
    error ConditionAlreadySet();
    error AlreadySettled();
    error AssertionNotSettled();
    error UnexpectedOutcome();

    /// @inheritdoc IConditionResolver
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        if (configs[escrowId].oracle != address(0)) revert ConditionAlreadySet();

        (address oracle, bytes32 assertionId, int256 expectedOutcome) = 
            abi.decode(data, (address, bytes32, int256));
        
        if (oracle == address(0)) revert InvalidOracle();
        if (assertionId == bytes32(0)) revert InvalidAssertionId();

        configs[escrowId] = Config({
            oracle: oracle,
            assertionId: assertionId,
            expectedOutcome: expectedOutcome,
            settled: false
        });

        emit ConditionSet(escrowId, oracle, assertionId, expectedOutcome);
    }

    /// @notice Settle the assertion and check outcome
    /// @param escrowId The escrow identifier
    function settleAssertion(uint256 escrowId) external {
        Config storage config = configs[escrowId];
        
        if (config.settled) revert AlreadySettled();

        int256 outcome = IOptimisticOracleV3(config.oracle).settleAndGetPrice(config.assertionId);

        if (outcome != config.expectedOutcome) revert UnexpectedOutcome();

        config.settled = true;
        emit AssertionSettled(escrowId, outcome);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        return configs[escrowId].settled;
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
