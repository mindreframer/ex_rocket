# EPIC004 Plan: BEAM Scheduler Isolation

## Progress

- [ ] Phase 4.1: Classify every exported NIF by blocking behavior.
- [ ] Phase 4.2: Move point operations to `DirtyIo`.
- [ ] Phase 4.3: Move storage-backed bulk operations to `DirtyIo`.
- [ ] Phase 4.4: Move iterator and snapshot operations to `DirtyIo`.
- [ ] Phase 4.5: Audit lifecycle and metadata scheduling.
- [ ] Phase 4.6: Add scheduler-responsiveness benchmarks.
- [ ] Phase 4.7: Run gates and commit.

## Implementation Steps

1. Record each NIF's native work, storage/lock risk, chosen scheduler, and rationale.
2. Migrate default and CF get/put/delete/merge paths that may touch storage.
3. Migrate multi-get, relevant existence checks, supported WAL flush, and remaining storage-backed bulk work.
4. Migrate iterator creation/advancement and all snapshot read/iterator paths, including both paging APIs.
5. Verify lifecycle, CF metadata, backup/checkpoint/restore, path/sequence metadata, and the planned close path.
6. Measure hot throughput, cold latency, scan throughput, dirty saturation, and independent BEAM heartbeats.
7. Run the full gate and commit `roadmap002 - epic 4 - isolate RocksDB NIF scheduling`.

## Quality Gate

- [ ] Every NIF is classified.
- [ ] No unjustified blocking NIF remains normal-scheduled.
- [ ] Scheduling inventory tests pass.
- [ ] Responsiveness/benchmark smoke passes.
- [ ] Full source gate passes.
- [ ] Only EPIC004 changes are committed.
