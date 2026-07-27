# EPIC004 Plan: Column Families

## Progress

- [x] Phase 4.1: Implement CF lifecycle.
- [x] Phase 4.2: Implement writable and read-only CF open.
- [x] Phase 4.3: Implement CF writes.
- [x] Phase 4.4: Implement CF reads and helpers.
- [x] Phase 4.5: Implement CF bulk operations.
- [x] Phase 4.6: Implement CF iterators.
- [x] Phase 4.7: Test and commit.

## Implementation Steps

1. Port create/drop/list behavior.
2. Port descriptor-based opens.
3. Resolve handles and perform put/delete.
4. Match get/default/term helper behavior.
5. Extend batches and bulk reads to CFs.
6. Port full and prefix CF iterators.
7. Run the full gate and commit `roadmap001 - epic 4 - column families`.

## Quality Gate

- [x] CF lifecycle tests pass.
- [x] CF data tests pass.
- [x] Full suite passes.
