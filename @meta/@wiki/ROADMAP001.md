# ROADMAP001: Parallel Maintained rust-rocksdb Backend

## Objective

Add a second, independent ExRocket implementation backed by the maintained [`rust-rocksdb`](https://github.com/zaidoon1/rust-rocksdb) crate. The existing `ExRocket` module and `native/rocker` crate remain intact throughout the work. The new backend is exposed as `ExRocket.RustRocksDB` and implemented by a separate `native/rocker_maintained` Rust NIF crate.

The required outcome is the same currently exposed Elixir API on the new module, dedicated parity tests, and benchmarks that can compare both implementations. Transparent backend switching is explicitly not required.

## Delivery Rules

- Exactly seven epics, each with exactly seven phases.
- Preserve the legacy `ExRocket` implementation and its tests.
- Add functionality incrementally to `ExRocket.RustRocksDB`.
- Keep API return shapes compatible with the current public API.
- Run the complete test suite after every epic.
- Commit each green epic separately with `roadmap001 - epic N - ...`.
- Do not remove either implementation during this roadmap.

## Architecture

```text
Elixir.ExRocket
  -> native/rocker
  -> rocksdb 0.24 / RocksDB 10.4.2

Elixir.ExRocket.RustRocksDB
  -> native/rocker_maintained
  -> maintained rust-rocksdb / current bundled RocksDB
```

The two native crates deliberately remain independent. Duplication is acceptable because it isolates migration risk and makes backend behavior directly comparable.

---

## EPIC001 — Parallel Backend Foundation

**Goal:** Establish the second crate, second Elixir module, build wiring, and an isolated smoke test without changing legacy behavior.

1. **Phase 1.1 — Dependency baseline:** Pin the maintained `rust-rocksdb` package and document its RocksDB and Rust requirements.
2. **Phase 1.2 — Native crate scaffold:** Create `native/rocker_maintained` with its own package, lockfile, and NIF library target.
3. **Phase 1.3 — Elixir module scaffold:** Add `ExRocket.RustRocksDB` with independent RustlerPrecompiled loading.
4. **Phase 1.4 — Resource foundation:** Register an independent database resource and implement `lxcode/0`.
5. **Phase 1.5 — Build integration:** Ensure the maintained crate builds through `FORCE_BUILD=yes mix compile`.
6. **Phase 1.6 — Smoke coverage:** Add tests proving both NIF modules load independently.
7. **Phase 1.7 — Gate and commit:** Run all tests and commit the green foundation.

## EPIC002 — Database Lifecycle And Core KV

**Goal:** Implement the minimum useful maintained backend: database lifecycle and basic key/value operations.

1. **Phase 2.1 — Option decoding baseline:** Port the core database option decoder needed by lifecycle operations.
2. **Phase 2.2 — Open operations:** Implement `open/2` and `open_for_read_only/2`.
3. **Phase 2.3 — Maintenance operations:** Implement `destroy/2` and `repair/2`.
4. **Phase 2.4 — Database metadata:** Implement `get_db_path/1` and `latest_sequence_number/1`.
5. **Phase 2.5 — Core writes:** Implement `put/3` and `delete/2`.
6. **Phase 2.6 — Core reads and helpers:** Implement `get/2`, `get/3`, and `getb/2` with legacy return shapes.
7. **Phase 2.7 — Gate and commit:** Add lifecycle/KV tests, run all tests, and commit.

## EPIC003 — Batches And Read Primitives

**Goal:** Complete efficient basic data access before adding advanced resource types.

1. **Phase 3.1 — Write batches:** Implement default-column-family batch put/delete operations.
2. **Phase 3.2 — Range deletion:** Implement `delete_range/3`.
3. **Phase 3.3 — Multi-get:** Implement `multi_get/2`.
4. **Phase 3.4 — Existence checks:** Implement `key_may_exist/2`.
5. **Phase 3.5 — Iterator resources:** Add maintained-backend iterator resource registration and ownership.
6. **Phase 3.6 — Iteration API:** Implement `iterator/2`, `iterator_range/5`, `prefix_iterator/2`, and `next/1`.
7. **Phase 3.7 — Gate and commit:** Add batch/read/iterator tests, run all tests, and commit.

## EPIC004 — Column Families

**Goal:** Provide complete column-family behavior on the maintained backend.

1. **Phase 4.1 — CF lifecycle:** Implement `create_cf/3`, `drop_cf/2`, and `list_cf/2`.
2. **Phase 4.2 — CF open:** Implement `open_cf/3` and `open_cf_for_read_only/3`.
3. **Phase 4.3 — CF writes:** Implement `put_cf/4` and `delete_cf/3`.
4. **Phase 4.4 — CF reads:** Implement `get_cf/3`, `get_cf/4`, and `get_cfb/3`.
5. **Phase 4.5 — CF bulk operations:** Implement CF write-batch operations, `delete_range_cf/4`, `multi_get_cf/2`, and `key_may_exist_cf/3`.
6. **Phase 4.6 — CF iteration:** Implement `iterator_cf/3` and `prefix_iterator_cf/3`.
7. **Phase 4.7 — Gate and commit:** Add CF parity tests, run all tests, and commit.

## EPIC005 — Snapshots, Checkpoints, And Backups

**Goal:** Port data-protection and consistent-read capabilities.

1. **Phase 5.1 — Snapshot resource:** Register and safely retain maintained-backend snapshots.
2. **Phase 5.2 — Snapshot reads:** Implement `snapshot/1`, `snapshot_get/2`, and `snapshot_get/3`.
3. **Phase 5.3 — Snapshot CF reads:** Implement `snapshot_get_cf/3` and `snapshot_get_cf/4`.
4. **Phase 5.4 — Snapshot bulk reads:** Implement `snapshot_multi_get/2` and `snapshot_multi_get_cf/2`.
5. **Phase 5.5 — Snapshot iteration:** Implement `snapshot_iterator/2` and `snapshot_iterator_cf/3`.
6. **Phase 5.6 — Protection APIs:** Implement checkpoints and all backup create/info/purge/restore functions.
7. **Phase 5.7 — Gate and commit:** Add protection/snapshot tests, run all tests, and commit.

## EPIC006 — Merge Operators And Full Options

**Goal:** Match merge behavior and the practical configuration surface already exposed by ExRocket.

1. **Phase 6.1 — Merge framework:** Port merge-operator registration to maintained rust-rocksdb APIs.
2. **Phase 6.2 — Default merges:** Implement `merge/3` and `mergeb/3`.
3. **Phase 6.3 — CF merges:** Implement `merge_cf/4` and `merge_cfb/4`.
4. **Phase 6.4 — Existing operators:** Port counter, Erlang-term, and bitset merge semantics.
5. **Phase 6.5 — Database options:** Port supported DB, compression, compaction, cache, and table options.
6. **Phase 6.6 — Read options:** Port iterator-range read options and validate option error behavior.
7. **Phase 6.7 — Gate and commit:** Add merge/options parity tests, run all tests, and commit.

## EPIC007 — API Parity, Benchmarks, And Release Readiness

**Goal:** Finish the complete parallel implementation and make it measurable and maintainable.

1. **Phase 7.1 — API inventory:** Mechanically verify every public `ExRocket` function exists on `ExRocket.RustRocksDB`.
2. **Phase 7.2 — Behavioral parity suite:** Run equivalent functional cases against both modules and resolve mismatched return shapes.
3. **Phase 7.3 — Error and resource tests:** Cover invalid handles, unknown CFs, read-only behavior, cleanup, and concurrent access.
4. **Phase 7.4 — Comparative benchmarks:** Add equivalent read/write workloads for both implementations.
5. **Phase 7.5 — Build and release wiring:** Add maintained-backend targets, artifact naming, checksum guidance, and CI compilation.
6. **Phase 7.6 — Documentation:** Document module choice, dependency versions, build requirements, known differences, and rollback/removal procedure.
7. **Phase 7.7 — Final gate and commit:** Run formatting, both native builds, all tests, and benchmarks; commit the completed roadmap.

---

## Definition Of Done

- `ExRocket` remains operational with the legacy native crate.
- `ExRocket.RustRocksDB` exposes the same public function names and arities.
- Both modules can be loaded and exercised in the same BEAM runtime.
- Existing tests remain green.
- Dedicated maintained-backend tests are green.
- Comparative benchmarks exist for both modules.
- Build and release documentation covers both native libraries.
- Seven independently tested epic commits exist.
