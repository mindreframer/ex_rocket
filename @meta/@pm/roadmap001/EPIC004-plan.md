# EPIC004 Plan: Column Families

## Progress

- [ ] Phase 4.1: Implement CF lifecycle.
- [ ] Phase 4.2: Implement writable and read-only CF open.
- [ ] Phase 4.3: Implement CF writes.
- [ ] Phase 4.4: Implement CF reads and helpers.
- [ ] Phase 4.5: Implement CF bulk operations.
- [ ] Phase 4.6: Implement CF iterators.
- [ ] Phase 4.7: Test and commit.

## Implementation Steps

1. Port create/drop/list behavior.
2. Port descriptor-based opens.
3. Resolve handles and perform put/delete.
4. Match get/default/term helper behavior.
5. Extend batches and bulk reads to CFs.
6. Port full and prefix CF iterators.
7. Run the full gate and commit `roadmap001 - epic 4 - column families`.

## Quality Gate

- [ ] CF lifecycle tests pass.
- [ ] CF data tests pass.
- [ ] Full suite passes.
