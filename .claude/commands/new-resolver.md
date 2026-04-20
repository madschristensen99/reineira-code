Build a new IConditionResolver contract based on this description: $ARGUMENTS

**Reference implementations** (use as scaffolding templates):
- `contracts/resolvers/TimeLockResolver.sol` — simplest time-based pattern
- `contracts/resolvers/ReclaimResolver.sol` — zkTLS proof submission with replay protection
- `contracts/resolvers/ChainlinkPriceResolver.sol` — oracle price feed with staleness validation
- `contracts/resolvers/UMAOptimisticResolver.sol` — prediction market settlement pattern

Follow these steps exactly:

1. Create the Solidity contract in `contracts/resolvers/`. Name it based on the description (PascalCase + "Resolver").
2. Implement `IConditionResolver` from `contracts/interfaces/IConditionResolver.sol` and `ERC165` from OpenZeppelin.
3. Use the storage pattern from reference resolvers — mapping for per-escrow config, strict validation in `onConditionSet`, pure logic in `isConditionMet`.
4. If the resolver needs proof submission (zkTLS, external data), follow `ReclaimResolver` pattern with `submitProof()` and replay protection (`mapping(bytes32 => bool) usedProofs`).
5. Add NatSpec documentation to all public functions.
6. Create a matching test file in `test/` using Forge test pattern. See `test/ReclaimResolver.t.sol` or `test/ChainlinkPriceResolver.t.sol` for examples. Include tests for: config storage, validation reverts, condition-not-met, condition-met, edge cases, and `supportsInterface`.
7. Verify against common mistakes in `.cursor/rules/01-resolver.mdc` before presenting.

**Critical requirements:**
- Pragma: `^0.8.24`
- Custom errors over require strings
- Emit events on state changes
- `isConditionMet` MUST be `view`
- Check `ConditionAlreadySet` in `onConditionSet`
- ERC-165 support required
