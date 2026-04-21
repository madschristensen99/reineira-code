// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReclaimResolver} from "../contracts/resolvers/ReclaimResolver.sol";
import {IConditionResolver} from "../contracts/interfaces/IConditionResolver.sol";

contract MockReclaimVerifier {
    mapping(bytes32 => bool) public validProofs;

    function setValidProof(bytes32 proofHash, bool valid) external {
        validProofs[proofHash] = valid;
    }

    function verifyProof(bytes calldata proof, bytes32) external view returns (bool) {
        bytes32 proofHash = keccak256(proof);
        return validProofs[proofHash] && keccak256(proof) == proofHash;
    }
}

contract ReclaimResolverTest is Test {
    ReclaimResolver public resolver;
    MockReclaimVerifier public verifier;

    uint256 constant ESCROW_ID = 1;
    bytes32 constant CLAIM_HASH = keccak256("PAYPAL_PAYMENT_RECEIVED");
    bytes validProof;

    function setUp() public {
        resolver = new ReclaimResolver();
        verifier = new MockReclaimVerifier();
        
        validProof = abi.encode("valid_proof_data", block.timestamp);
        bytes32 proofHash = keccak256(validProof);
        verifier.setValidProof(proofHash, true);
    }

    function test_OnConditionSet() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);

        vm.expectEmit(true, false, false, true);
        emit ReclaimResolver.ConditionSet(ESCROW_ID, address(verifier), CLAIM_HASH);

        resolver.onConditionSet(ESCROW_ID, data);

        (address storedVerifier, bytes32 storedHash, bool fulfilled) = resolver.configs(ESCROW_ID);
        assertEq(storedVerifier, address(verifier));
        assertEq(storedHash, CLAIM_HASH);
        assertFalse(fulfilled);
    }

    function test_OnConditionSet_RevertsIfZeroVerifier() public {
        bytes memory data = abi.encode(address(0), CLAIM_HASH);

        vm.expectRevert(ReclaimResolver.InvalidVerifier.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfZeroClaimHash() public {
        bytes memory data = abi.encode(address(verifier), bytes32(0));

        vm.expectRevert(ReclaimResolver.InvalidClaimHash.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_OnConditionSet_RevertsIfAlreadySet() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);

        vm.expectRevert(ReclaimResolver.ConditionAlreadySet.selector);
        resolver.onConditionSet(ESCROW_ID, data);
    }

    function test_SubmitProof() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);

        bytes32 proofHash = keccak256(validProof);
        vm.expectEmit(true, false, false, true);
        emit ReclaimResolver.ProofSubmitted(ESCROW_ID, proofHash);

        resolver.submitProof(ESCROW_ID, validProof);

        (, , bool fulfilled) = resolver.configs(ESCROW_ID);
        assertTrue(fulfilled);
        assertTrue(resolver.usedProofs(proofHash));
    }

    function test_SubmitProof_RevertsIfAlreadyFulfilled() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);
        resolver.submitProof(ESCROW_ID, validProof);

        vm.expectRevert(ReclaimResolver.AlreadyFulfilled.selector);
        resolver.submitProof(ESCROW_ID, validProof);
    }

    function test_SubmitProof_RevertsIfProofReused() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);
        resolver.submitProof(ESCROW_ID, validProof);

        uint256 escrowId2 = 2;
        resolver.onConditionSet(escrowId2, data);

        vm.expectRevert(ReclaimResolver.ProofAlreadyUsed.selector);
        resolver.submitProof(escrowId2, validProof);
    }

    function test_SubmitProof_RevertsIfInvalidProof() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);

        bytes memory invalidProof = abi.encode("invalid_proof");

        vm.expectRevert(ReclaimResolver.InvalidProof.selector);
        resolver.submitProof(ESCROW_ID, invalidProof);
    }

    function test_IsConditionMet_ReturnsFalseBeforeProof() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);

        assertFalse(resolver.isConditionMet(ESCROW_ID));
    }

    function test_IsConditionMet_ReturnsTrueAfterProof() public {
        bytes memory data = abi.encode(address(verifier), CLAIM_HASH);
        resolver.onConditionSet(ESCROW_ID, data);
        resolver.submitProof(ESCROW_ID, validProof);

        assertTrue(resolver.isConditionMet(ESCROW_ID));
    }

    function test_SupportsInterface() public view {
        bytes4 resolverInterface = type(IConditionResolver).interfaceId;
        assertTrue(resolver.supportsInterface(resolverInterface));
    }

    function testFuzz_OnConditionSet(address fuzzVerifier, bytes32 fuzzClaimHash) public {
        vm.assume(fuzzVerifier != address(0));
        vm.assume(fuzzClaimHash != bytes32(0));

        bytes memory data = abi.encode(fuzzVerifier, fuzzClaimHash);
        resolver.onConditionSet(ESCROW_ID, data);

        (address storedVerifier, bytes32 storedHash, ) = resolver.configs(ESCROW_ID);
        assertEq(storedVerifier, fuzzVerifier);
        assertEq(storedHash, fuzzClaimHash);
    }
}
