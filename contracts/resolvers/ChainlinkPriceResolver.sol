// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IConditionResolver} from "../interfaces/IConditionResolver.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IChainlinkFeed {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @title ChainlinkPriceResolver
/// @notice Oracle-based condition resolver using Chainlink price feeds
/// @dev Releases escrow when price crosses threshold with freshness validation
contract ChainlinkPriceResolver is IConditionResolver, ERC165 {
    struct Config {
        address priceFeed;
        int256 threshold;
        bool aboveThreshold;
        uint256 maxStaleness;
    }

    mapping(uint256 => Config) public configs;

    event ConditionSet(uint256 indexed escrowId, address priceFeed, int256 threshold, bool aboveThreshold, uint256 maxStaleness);

    error InvalidPriceFeed();
    error InvalidThreshold();
    error InvalidStaleness();
    error ConditionAlreadySet();
    error StalePrice();
    error InvalidRoundData();

    /// @inheritdoc IConditionResolver
    function onConditionSet(uint256 escrowId, bytes calldata data) external {
        if (configs[escrowId].priceFeed != address(0)) revert ConditionAlreadySet();

        (address priceFeed, int256 threshold, bool aboveThreshold, uint256 maxStaleness) = 
            abi.decode(data, (address, int256, bool, uint256));
        
        if (priceFeed == address(0)) revert InvalidPriceFeed();
        if (threshold <= 0) revert InvalidThreshold();
        if (maxStaleness == 0 || maxStaleness > 1 days) revert InvalidStaleness();

        configs[escrowId] = Config({
            priceFeed: priceFeed,
            threshold: threshold,
            aboveThreshold: aboveThreshold,
            maxStaleness: maxStaleness
        });

        emit ConditionSet(escrowId, priceFeed, threshold, aboveThreshold, maxStaleness);
    }

    /// @inheritdoc IConditionResolver
    function isConditionMet(uint256 escrowId) external view returns (bool) {
        Config memory config = configs[escrowId];
        
        if (config.priceFeed == address(0)) return false;

        (uint80 roundId, int256 answer, , uint256 updatedAt, uint80 answeredInRound) = 
            IChainlinkFeed(config.priceFeed).latestRoundData();

        if (answeredInRound < roundId) revert InvalidRoundData();
        if (block.timestamp - updatedAt > config.maxStaleness) revert StalePrice();
        if (answer <= 0) revert InvalidRoundData();

        if (config.aboveThreshold) {
            return answer >= config.threshold;
        } else {
            return answer <= config.threshold;
        }
    }

    /// @inheritdoc ERC165
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
