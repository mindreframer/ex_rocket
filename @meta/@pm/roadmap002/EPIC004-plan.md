# EPIC004 Plan: BEAM Scheduler Isolation

## Progress

- [x] Phase 4.1: Classify every exported NIF by blocking behavior.
- [x] Phase 4.2: Move point operations to `DirtyIo`.
- [x] Phase 4.3: Move storage-backed bulk operations to `DirtyIo`.
- [x] Phase 4.4: Move iterator and snapshot operations to `DirtyIo`.
- [x] Phase 4.5: Audit lifecycle and metadata scheduling.
- [x] Phase 4.6: Add scheduler-responsiveness benchmarks.
- [x] Phase 4.7: Run gates and commit.

## Implementation Steps

1. Record each NIF's native work, storage/lock risk, chosen scheduler, and rationale.
2. Migrate default and CF get/put/delete/merge paths that may touch storage.
3. Migrate multi-get, relevant existence checks, supported WAL flush, and remaining storage-backed bulk work.
4. Migrate iterator creation/advancement and all snapshot read/iterator paths, including both paging APIs.
5. Verify lifecycle, CF metadata, backup/checkpoint/restore, path/sequence metadata, and the planned close path.
6. Measure hot throughput, cold latency, scan throughput, dirty saturation, and independent BEAM heartbeats.
7. Run the full gate and commit `roadmap002 - epic 4 - isolate RocksDB NIF scheduling`.

## Quality Gate

- [x] Every NIF is classified.
- [x] No unjustified blocking NIF remains normal-scheduled.
- [x] Scheduling inventory tests pass.
- [x] Responsiveness/benchmark smoke passes.
- [x] Full source gate passes.
- [x] Only EPIC004 changes are committed.
