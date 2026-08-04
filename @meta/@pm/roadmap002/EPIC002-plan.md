# EPIC002 Plan: Durable Write Boundaries

## Progress

- [x] Phase 2.1: Add the native write-options decoder.
- [x] Phase 2.2: Implement `write_batch/3` through `DB::write_opt`.
- [x] Phase 2.3: Preserve `write_batch/2` through compatibility delegation.
- [x] Phase 2.4: Add exact durability-option validation.
- [x] Phase 2.5: Implement the conditional WAL flush boundary.
- [x] Phase 2.6: Add crash-process durability tests.
- [x] Phase 2.7: Run gates and commit.

## Implementation Steps

1. Decode only `sync` and `disable_wal`, preserving WAL-enabled/non-sync defaults.
2. Validate all existing default/CF operation tuples and execute one batch with one `WriteOptions` value.
3. Delegate `write_batch/2` to the default `write_batch/3` path and retain legacy shapes/counts.
4. Reject unknown keys, non-booleans, and contradictory sync/WAL combinations before mutation.
5. If EPIC001 confirms API support, expose `DB::flush_wal(sync)` on `DirtyIo` with native sync semantics; otherwise document the unsupported API and omission.
6. In an independent OS process or BEAM instance, test dirty/data/clean ordering, source-cursor advancement only after clean success, forced termination, and reopen.
7. Run the full gate and commit `roadmap002 - epic 2 - add durable write boundaries`.

## Quality Gate

- [x] Compatibility and atomicity tests pass.
- [x] Write-option validation tests pass.
- [x] Crash/reopen durability tests pass.
- [x] Native source build passes.
- [x] Full suite passes.
- [x] Only EPIC002 changes are committed.
