// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {UMAOptimisticResolver} from "../contracts/resolvers/UMAOptimisticResolver.sol";
import {IConditionResolver} from "../contracts/interfaces/IConditionResolver.sol";

contract MockOptimisticOracleV3 {
    mapping(bytes32 => int256) public assertionOutcomes;
    mapping(bytes32 => bool) public assertionSettled;

    function setAssertion(bytes32 assertionId, int256 outcome, bool settled) external {
        assertionOutcomes[assertionId] = outcome;
        assertionSettled[assertionId] = settled;
    }

    function settleAndGetPrice(bytes32 assertionId) external view returns (int256) {
        require(assertionSettled[assertionId], "Assertion not settled");
        return assertionOutcomes[assertionId];
    }

    function getAssertion(bytes32 assertionId) external view returns (bool settled, int256 price) {
        return (assertionSettled[assertionId], assertionOutcomes[assertionId]);
    }
}

contract UMAOptimisticResolverTest is Test {
    UMAOptimisticResolver public resolver;
    MockOptimisticOracleV3 public oracle;

    uint256 constant ESCROW_ID = 1;
    bytes32 constant ASSERTION_ID = keccak256("MARKET_OUTCOME_YES");
    int256 constant EXPECTED_OUTCOME = 1e18;

    function setUp() public {
        resolver = new UMAOptimisticResolver();
        oracle = new MockOptimisticOracleV3();
    }

    function test_OnConditionSet() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);

        vm.expectEmit(true, false, false, true);
        emit UMAOptimisticResolver.ConditionSet(ESCROW_ID, address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);

        resolver.onConditionSet(ESCROW_ID, data);

        (address storedOracle, bytes32 storedAssertion, int256 storedOutcome, bool settled) = 
            resolver.configs(ESCROW_ID);
        assertEq(storedOracle, address(oracle));
        assertEq(storedAssertion, ASSERTION_ID);
        assertEq(storedOutcome, EXPECTED_OUTCOME);
        assertFalse(settled);
    }

    function test_OnConditionSet_RevertsIfZeroOracle() public {
        bytes memory data = abi.encode(address(0), ASSERTION_ID, EXPECTED_OUTCOME);

        vm.expectRevert(UMAOptimisticResolver.InvalidOracle.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfZeroAssertionId() public {
        bytes memory data = abi.encode(address(oracle), bytes32(0), EXPECTED_OUTCOME);

        vm.expectRevert(UMAOptimisticResolver.InvalidAssertionId.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfAlreadySet() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert(UMAOptimisticResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_SettleAssertion_Success() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        oracle.setAssertion(ASSERTION_ID, EXPECTED_OUTCOME, true);

        vm.expectEmit(true, false, false, true);
        emit UMAOptimisticResolver.AssertionSettled(ESCROW_ID, EXPECTED_OUTCOME);

        resolver.settleAssertion(ESCROW_ID);

        (, , , bool settled) = resolver.configs(ESCROW_ID);
        assertTrue(settled);
    }

    function test_SettleAssertion_RevertsIfAlreadySettled() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        oracle.setAssertion(ASSERTION_ID, EXPECTED_OUTCOME, true);
        resolver.settleAssertion(ESCROW_ID);

        vm.expectRevert(UMAOptimisticResolver.AlreadySettled.selector);
        resolver.settleAssertion(ESCROW_ID);
    }

    function test_SettleAssertion_RevertsIfUnexpectedOutcome() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        oracle.setAssertion(ASSERTION_ID, 0, true);

        vm.expectRevert(UMAOptimisticResolver.UnexpectedOutcome.selector);
        resolver.settleAssertion(ESCROW_ID);
    }

    function test_SettleAssertion_RevertsIfNotSettledYet() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        oracle.setAssertion(ASSERTION_ID, EXPECTED_OUTCOME, false);

        vm.expectRevert("Assertion not settled");
        resolver.settleAssertion(ESCROW_ID);
    }

    function test_IsConditionMet_ReturnsFalseBeforeSettlement() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_ReturnsTrueAfterSettlement() public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, EXPECTED_OUTCOME);
        resolver.onConditionSet(ESCROW_ID, data);

        oracle.setAssertion(ASSERTION_ID, EXPECTED_OUTCOME, true);
        resolver.settleAssertion(ESCROW_ID);

        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_SupportsInterface() public view {
        bytes4 resolverInterface = type(IConditionResolver).interfaceId;
        assertTrue(resolver.supportsInterface(resolverInterface));
    }

    function testFuzz_OnConditionSet(address fuzzOracle, bytes32 fuzzAssertion, int256 fuzzOutcome) public {
        vm.assume(fuzzOracle != address(0));
        vm.assume(fuzzAssertion != bytes32(0));

        bytes memory data = abi.encode(fuzzOracle, fuzzAssertion, fuzzOutcome);
        resolver.onConditionSet(ESCROW_ID, data);

        (address storedOracle, bytes32 storedAssertion, int256 storedOutcome, ) = 
            resolver.configs(ESCROW_ID);
        assertEq(storedOracle, fuzzOracle);
        assertEq(storedAssertion, fuzzAssertion);
        assertEq(storedOutcome, fuzzOutcome);
    }

    function testFuzz_SettleAssertion_MatchingOutcome(int256 outcome) public {
        bytes memory data = abi.encode(address(oracle), ASSERTION_ID, outcome);
        resolver.onConditionSet(ESCROW_ID, data);

        oracle.setAssertion(ASSERTION_ID, outcome, true);
        resolver.settleAssertion(ESCROW_ID);

        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }
}
