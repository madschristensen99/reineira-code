// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChainlinkPriceResolver} from "../contracts/resolvers/ChainlinkPriceResolver.sol";
import {IConditionResolver} from "../contracts/interfaces/IConditionResolver.sol";

contract MockChainlinkFeed {
    int256 public price;
    uint256 public updatedAt;
    uint80 public roundId;

    function setPrice(int256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
        roundId++;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        updatedAt = _updatedAt;
    }

    function latestRoundData()
        external
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (roundId, price, 0, updatedAt, roundId);
    }
}

contract ChainlinkPriceResolverTest is Test {
    ChainlinkPriceResolver public resolver;
    MockChainlinkFeed public priceFeed;

    uint256 constant ESCROW_ID = 1;
    int256 constant THRESHOLD = 2000e8;
    uint256 constant MAX_STALENESS = 1 hours;

    function setUp() public {
        resolver = new ChainlinkPriceResolver();
        priceFeed = new MockChainlinkFeed();
        priceFeed.setPrice(1800e8);
    }

    function test_OnConditionSet_AboveThreshold() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);

        vm.expectEmit(true, false, false, true);
        emit ChainlinkPriceResolver.ConditionSet(ESCROW_ID, address(priceFeed), THRESHOLD, true, MAX_STALENESS);

        resolver.onConditionSet(ESCROW_ID, data);

        (address storedFeed, int256 storedThreshold, bool storedAbove, uint256 storedStaleness) = 
            resolver.configs(ESCROW_ID);
        assertEq(storedFeed, address(priceFeed));
        assertEq(storedThreshold, THRESHOLD);
        assertTrue(storedAbove);
        assertEq(storedStaleness, MAX_STALENESS);
    }

    function test_OnConditionSet_BelowThreshold() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, false, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        (, , bool storedAbove, ) = resolver.configs(ESCROW_ID);
        assertFalse(storedAbove);
    }

    function test_OnConditionSet_RevertsIfZeroFeed() public {
        bytes memory data = abi.encode(address(0), THRESHOLD, true, MAX_STALENESS);

        vm.expectRevert(ChainlinkPriceResolver.InvalidPriceFeed.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfZeroThreshold() public {
        bytes memory data = abi.encode(address(priceFeed), int256(0), true, MAX_STALENESS);

        vm.expectRevert(ChainlinkPriceResolver.InvalidThreshold.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfNegativeThreshold() public {
        bytes memory data = abi.encode(address(priceFeed), int256(-100), true, MAX_STALENESS);

        vm.expectRevert(ChainlinkPriceResolver.InvalidThreshold.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfZeroStaleness() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, uint256(0));

        vm.expectRevert(ChainlinkPriceResolver.InvalidStaleness.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfExcessiveStaleness() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, 2 days);

        vm.expectRevert(ChainlinkPriceResolver.InvalidStaleness.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfAlreadySet() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert(ChainlinkPriceResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_IsConditionMet_AboveThreshold_False() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(1800e8);
        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_AboveThreshold_True() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(2100e8);
        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_AboveThreshold_TrueAtExactThreshold() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(THRESHOLD);
        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_BelowThreshold_True() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, false, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(1800e8);
        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_BelowThreshold_False() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, false, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(2100e8);
        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_RevertsIfStale() public {
        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(2100e8);
        uint256 staleTimestamp = block.timestamp;
        
        vm.warp(block.timestamp + MAX_STALENESS + 1);
        priceFeed.setUpdatedAt(staleTimestamp);

        vm.expectRevert(ChainlinkPriceResolver.StalePrice.selector);
        resolver.isConditionMet(ESCROW_ID);
    }

    function test_IsConditionMet_ReturnsFalseIfNotConfigured() public view {
        assertFalse(resolver.isConditionMet(999));
    }

    function test_SupportsInterface() public view {
        bytes4 resolverInterface = type(IConditionResolver).interfaceId;
        assertTrue(resolver.supportsInterface(resolverInterface));
    }

    function testFuzz_IsConditionMet_AboveThreshold(int256 price) public {
        vm.assume(price > 0);
        vm.assume(price < type(int256).max);

        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, true, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(price);

        bool result = resolver.isConditionMet(ESCROW_ID);
        assertEq(result, price >= THRESHOLD);
    }

    function testFuzz_IsConditionMet_BelowThreshold(int256 price) public {
        vm.assume(price > 0);
        vm.assume(price < type(int256).max);

        bytes memory data = abi.encode(address(priceFeed), THRESHOLD, false, MAX_STALENESS);
        resolver.onConditionSet(ESCROW_ID, data);

        priceFeed.setPrice(price);

        bool result = resolver.isConditionMet(ESCROW_ID);
        assertEq(result, price <= THRESHOLD);
    }
}
