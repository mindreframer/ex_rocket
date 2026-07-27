# EPIC001 Plan: Parallel Backend Foundation

## Progress

- [x] Phase 1.1: Pin and document the maintained dependency baseline.
- [x] Phase 1.2: Scaffold `native/rocker_maintained`.
- [x] Phase 1.3: Scaffold `ExRocket.RustRocksDB`.
- [x] Phase 1.4: Register resources and implement `lxcode/0`.
- [x] Phase 1.5: Integrate source builds.
- [x] Phase 1.6: Add dual-load smoke coverage.
- [x] Phase 1.7: Run gates and commit.

## Implementation Steps

1. Record package, bundled RocksDB, and MSRV versions.
2. Create an isolated Rustler dylib crate and lockfile.
3. Add an independent RustlerPrecompiled Elixir loader.
4. Initialize NIF resources and backend identity.
5. Compile with `FORCE_BUILD=yes` without changing legacy loading.
6. Test both modules in one runtime.
7. Run the full quality gate and commit `roadmap001 - epic 1 - parallel backend foundation`.

## Quality Gate

- [x] Format checks pass.
- [x] Both native crates compile.
- [x] Focused tests pass.
- [x] Full tests pass.
- [x] Only EPIC001 changes are committed.
