# EPIC005 Plan: Safe Explicit Database Closure

## Progress

- [ ] Phase 5.1: Refactor `DbResource` to explicit open/closed state.
- [ ] Phase 5.2: Add race-safe dependency lease accounting.
- [ ] Phase 5.3: Integrate regular and CF iterator lifecycles.
- [ ] Phase 5.4: Integrate snapshot and snapshot-iterator lifecycles.
- [ ] Phase 5.5: Implement idempotent `close/1` on `DirtyIo`.
- [ ] Phase 5.6: Add race, path-lock, process-exit, and GC tests.
- [ ] Phase 5.7: Run gates and commit.

## Implementation Steps

1. Store `Option<DB>` behind the database lock and centralize helpers returning `:closed`.
2. Acquire/release dependent leases while database locking prevents child-creation/close races.
3. Cover successful and failed construction plus destruction for regular and CF iterators.
4. Let snapshots own one database lease and snapshot iterators retain snapshots without double counting.
5. Under exclusive state, return busy for leases or take/drop RocksDB before success; make repeat close succeed.
6. Repeat close/operation/creation races and verify process exit, immediate reopen/destroy, GC fallback, and supported sanitizers.
7. Run the full gate and commit `roadmap002 - epic 5 - add safe explicit close`.

## Quality Gate

- [ ] Closed/busy contract tests pass.
- [ ] Child lease tests pass.
- [ ] Path reuse and GC tests pass.
- [ ] Repeated race tests pass.
- [ ] Supported sanitizer runs pass or record a platform skip reason.
- [ ] Full source gate passes.
- [ ] Only EPIC005 changes are committed.
