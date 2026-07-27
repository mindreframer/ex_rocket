# EPIC006 Plan: Merge Operators And Full Options

## Progress

- [x] Phase 6.1: Port merge framework.
- [x] Phase 6.2: Implement default merges.
- [x] Phase 6.3: Implement CF merges.
- [x] Phase 6.4: Port all existing operators.
- [x] Phase 6.5: Port database/table options.
- [x] Phase 6.6: Port read options and validation.
- [x] Phase 6.7: Test and commit.

## Implementation Steps

1. Adapt callback signatures to maintained rust-rocksdb.
2. Expose binary and Erlang-term default merges.
3. Resolve CF handles for merges.
4. Verify counter, term, and bitset semantics.
5. Adapt renamed/removed settings deliberately.
6. Port read-bound and iterator options.
7. Run the full gate and commit `roadmap001 - epic 6 - merge operators and options`.

## Quality Gate

- [x] Merge tests pass.
- [x] Option tests pass.
- [x] Full suite passes.
