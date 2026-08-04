# EPIC003 Plan: Bounded Bulk Iteration

## Progress

- [x] Phase 3.1: Finalize iterator-take bounds and status semantics.
- [x] Phase 3.2: Implement the native bounded extraction loop.
- [x] Phase 3.3: Enforce entry and payload-memory bounds.
- [x] Phase 3.4: Cover every iterator variant.
- [x] Phase 3.5: Verify continuation and snapshot correctness.
- [x] Phase 3.6: Add comparative iterator throughput benchmarks.
- [x] Phase 3.7: Run gates and commit.

## Implementation Steps

1. Select/document hard limits and freeze option, progress, ordering, result, and status contracts.
2. Advance `IteratorResource` under one lock and return ordered binary key/value pairs.
3. Stop at entry/payload bounds without look-ahead; permit one oversized first row for progress.
4. Exercise standard, range, prefix, reverse, CF, snapshot, and snapshot-CF resources.
5. Prove exact-once repeated paging, position retention, boundary statuses, and snapshot stability.
6. Compare `next/1` and `iterator_take/2` across representative key/value sizes, warm/cold scans, multiple limits, and one stable snapshot.
7. Run the full gate and commit `roadmap002 - epic 3 - add bounded bulk iteration`.

## Quality Gate

- [x] Boundary and progress tests pass.
- [x] All iterator-owner tests pass.
- [x] Snapshot stability tests pass.
- [x] Benchmark smoke passes.
- [x] Full source gate passes.
- [x] Only EPIC003 changes are committed.
