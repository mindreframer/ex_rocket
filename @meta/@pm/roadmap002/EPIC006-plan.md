# EPIC006 Plan: Exact Configuration And Documentation

## Progress

- [x] Phase 6.1: Build the canonical public option inventory.
- [x] Phase 6.2: Reject unknown options with structured errors.
- [x] Phase 6.3: Enforce exact value and combination validation.
- [x] Phase 6.4: Complete reference documentation.
- [x] Phase 6.5: Add executable documentation examples.
- [x] Phase 6.6: Write ExRocket 0.5.0 migration guidance.
- [x] Phase 6.7: Run gates and commit.

## Implementation Steps

1. Inventory database/read/write/iterator keys, types, defaults, native mappings, and documentation status.
2. Reject unknown and misspelled keys before resource open/mutation and report the offending key.
3. Give every invalid-value/combination class a tested programmatic result without native panic or string parsing.
4. Update README, cheatsheet, module docs, changelog draft, and examples for all ADR002 contracts.
5. Execute representative documented option, durability, iteration, and lifecycle examples in CI/tests.
6. Explain strict 0.5.0 validation, configuration audits, on-disk compatibility, rollback, and checkpoint choices.
7. Run the full gate and commit `roadmap002 - epic 6 - enforce exact configuration`.

## Quality Gate

- [x] Canonical inventory checks pass.
- [x] Unknown/value validation tests pass.
- [x] Documentation checks/examples pass.
- [x] 0.5.0 migration notes are complete.
- [x] Full source gate passes.
- [x] Only EPIC006 changes are committed.
