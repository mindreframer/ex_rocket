# ROADMAP002: Consistency, Durability, And Lifecycle Improvements

**Status:** Complete (ExRocket 0.5.0)

## Objective

Implement the consistency improvements defined by
[`ADR002-consistency-improvements.md`](../@adr/ADR002-consistency-improvements.md)
for ExRocket's maintained `rust-rocksdb` backend.

The roadmap will add:

- Explicit per-batch RocksDB write durability options.
- Synchronous WAL durability boundaries suitable for trusted checkpoints.
- A bounded bulk iterator API.
- Dirty-I/O scheduling for potentially blocking RocksDB NIF operations.
- Safe and deterministic `close/1` semantics.
- Exact iterator documentation and strict option validation.
- Crash, lifecycle, scheduler-responsiveness, and release-artifact verification.

The expected release is ExRocket 0.5.0 because unknown option keys will change
from being silently ignored to being explicitly rejected. Existing on-disk
RocksDB databases remain compatible and require no migration.

## Source Baseline

The implementation starts from ExRocket 0.4.1:

```text
Elixir API:       ExRocket
Native crate:     native/rocker
Rust package:     rust-rocksdb 0.51
Bundled RocksDB:  11.1.2
Rust toolchain:   1.91
NIF version:      2.16
```

Relevant current implementation facts:

- `DbResource` contains `RwLock<DB>`.
- Iterators retain a `ResourceArc<DbResource>`.
- Snapshots retain a `ResourceArc<DbResource>`.
- `write_batch/2` calls `DB::write` without caller-controlled `WriteOptions`.
- `write_batch` and range deletion use `DirtyIo`.
- Point operations, iterator creation, `next/1`, and snapshot reads currently
  run as normal NIFs.
- `next/1` returns `:end_of_iterator` in code and tests.
- `CHEATSHEET.md` incorrectly documents `:end_of_table`.
- Native database options use canonical keys such as `set_max_open_files`.
- Unknown database option keys are silently ignored.

## Authoritative Semantics

ADR002 is authoritative for the intended behavior. This roadmap defines the
implementation order and acceptance gates. If implementation reveals a conflict
with ADR002, update the ADR explicitly before changing the contract.

The following distinctions must remain clear throughout delivery:

- **Atomicity:** all operations in a RocksDB write batch become visible together.
- **Durability:** acknowledged writes survive the stated failure model.
- **Iterator consistency:** pages from one iterator retain that iterator's view.
- **Scheduler isolation:** storage latency does not block normal BEAM schedulers.
- **Lifecycle safety:** RocksDB is never dropped while native children depend on it.

## Delivery Rules

- Exactly seven epics, each with exactly seven phases.
- Preserve all existing public functions and default behavior unless this
  roadmap explicitly identifies a stricter 0.5.0 contract.
- Keep `write_batch/2` and `next/1` operational.
- Do not change the RocksDB on-disk format or require data migration.
- Do not parse RocksDB error strings to implement lifecycle or validation logic.
- New programmatic conditions use stable atoms or structured error values.
- Every potentially unsafe resource-lifetime change must have native race tests.
- Every durability claim must identify its failure model and WAL assumptions.
- Run the complete source-built validation gate after every epic.
- Commit every green epic separately as `roadmap002 - epic N - ...`.
- Do not publish or tag 0.5.0 until EPIC007 is complete.

## Validation Gate

EPIC001 will add a focused `scripts/roadmap002_check.sh`. Until then, run the
equivalent commands directly:

```sh
export RUSTUP_TOOLCHAIN=1.91.0
export FORCE_BUILD=yes
mix format --check-formatted
cargo fmt --manifest-path native/rocker/Cargo.toml -- --check
mix clean
mix compile --warnings-as-errors
mix test
```

The final gate also includes native linting, crash subprocess tests, benchmarks,
precompiled-NIF smoke tests, and package-content verification.

## Compatibility Policy

### Must remain compatible

- Existing database files.
- Existing binary keys and values.
- Existing column families.
- Existing merge operators.
- Existing batch operation tuples.
- Existing return shapes for existing successful operations.
- `write_batch/2` defaults: WAL enabled and no synchronous flush requested.
- `next/1` terminal value: `:end_of_iterator`.
- Garbage-collection-based cleanup when `close/1` is not called.

### Additive public API

The roadmap intends to add:

```elixir
ExRocket.write_batch(db, operations, write_options)
ExRocket.flush_wal(db, sync)
ExRocket.iterator_take(iterator, options)
ExRocket.close(db)
```

`flush_wal/2` is conditional on confirming the exact supported
`rust-rocksdb 0.51` API. If unavailable, the roadmap must document the reason
and retain synchronous `write_batch/3` as the required durability boundary.

### Intentionally stricter 0.5.0 behavior

Unknown database, read, write, and iterator option keys must fail visibly rather
than being silently ignored.

## Target API Contracts

### Durable write batches

```elixir
ExRocket.write_batch(db, operations, %{
  sync: true,
  disable_wal: false
})
```

Defaults remain:

```elixir
%{sync: false, disable_wal: false}
```

`sync: true` combined with `disable_wal: true` is invalid because it appears to
request a WAL durability guarantee while disabling the WAL.

### Bounded iterator reads

```elixir
ExRocket.iterator_take(iterator, %{
  max_entries: 1_000,
  max_bytes: 4 * 1024 * 1024
})
```

Expected result:

```elixir
{:ok, [{key, value}], :more}
{:ok, [{key, value}], :end_of_iterator}
```

The supplied iterator advances. The API must enforce hard native bounds and
must always make progress when the first entry exceeds `max_bytes`.

### Explicit close

```elixir
:ok = ExRocket.close(db)
:ok = ExRocket.close(db)
{:error, :closed} = ExRocket.get(db, "key")
```

Close must return `{:error, :resource_busy}` while a live iterator or snapshot
requires the database.

## Target Native Architecture

```text
ExRocket Elixir facade
  |
  +-- default-arity compatibility delegates
  |
  +-- Rustler NIF boundary
        |
        +-- DbResource
        |     db: RwLock<Option<DB>>
        |     dependent lease count
        |
        +-- IteratorResource
        |     iterator mutex
        |     database or snapshot owner
        |     lifecycle lease
        |
        +-- SnapshotResource
              snapshot mutex
              database owner
              lifecycle lease
```

The exact Rust structure may differ, but it must preserve these properties:

1. Closing takes exclusive control of database state.
2. New dependent resources cannot race successfully with close.
3. Active iterators and snapshots prevent close.
4. Successful close drops RocksDB before returning.
5. Post-close operations return stable errors without panics or use-after-free.
6. Normal Rustler resource destruction remains safe if explicit close is omitted.

---

## EPIC001 — Contract Baseline And Validation Harness

**Goal:** Freeze current behavior, define the new public contracts, correct
known documentation drift, and establish a repeatable source-built gate before
native behavior changes.

1. **Phase 1.1 — API and implementation inventory:** Record every public
   function name/arity, native NIF export, scheduler class, resource dependency,
   option decoder, and existing return shape relevant to ADR002.
2. **Phase 1.2 — Behavioral baseline tests:** Add focused regression tests for
   existing `write_batch/2`, `next/1`, iterator ownership, snapshot ownership,
   path locking, garbage-collection closure, option handling, and exact current
   terminal atoms.
3. **Phase 1.3 — Public contract stubs:** Add types/specifications and NIF stubs
   for `write_batch/3`, `iterator_take/2`, and `close/1`; add `flush_wal/2` only
   after confirming native support. Tests must define intended result shapes.
4. **Phase 1.4 — Error vocabulary:** Add stable atoms or structured values for
   `closed`, `resource_busy`, invalid write options, invalid iterator options,
   and unknown options without requiring callers to parse strings.
5. **Phase 1.5 — Documentation correction:** Correct the iterator terminal value
   to `:end_of_iterator`, correct option examples to canonical native names, and
   clearly distinguish write atomicity from synchronous durability.
6. **Phase 1.6 — Validation script:** Add `scripts/roadmap002_check.sh` covering
   Elixir formatting, Rust formatting, a forced source build with warnings as
   errors, the complete test suite, and arguments/defaults that work in a clean
   checkout.
7. **Phase 1.7 — Gate and commit:** Run the full baseline gate, preserve all
   existing tests, verify no database-format changes, and commit the green
   contract foundation.

### EPIC001 acceptance evidence

- Existing public API inventory is mechanically captured.
- Current semantics are protected by focused tests before native refactoring.
- New APIs have one documented contract each.
- Documentation no longer says `:end_of_table`.
- Documented option examples use accepted option names.
- The source-built validation script passes from a clean build.

## EPIC002 — Durable Write Boundaries

**Goal:** Expose RocksDB write durability without changing existing
`write_batch/2` defaults or batch atomicity.

1. **Phase 2.1 — Native write-options decoder:** Add a dedicated Rust decoder
   for `sync` and `disable_wal`, with exact key/type validation and defaults that
   match RocksDB and ExRocket 0.4.1 behavior.
2. **Phase 2.2 — `write_batch/3`:** Build `rocksdb::WriteOptions`, apply it via
   `DB::write_opt`, preserve operation ordering/counts, and support all existing
   default and column-family batch tuples.
3. **Phase 2.3 — Compatibility delegation:** Implement `write_batch/2` as the
   exact default-options path and prove its success/error behavior remains
   unchanged.
4. **Phase 2.4 — Durability validation:** Reject unknown write options,
   non-boolean values, and `sync: true` with `disable_wal: true`; return stable
   validation errors before attempting a native write.
5. **Phase 2.5 — WAL flush boundary:** Implement and document `flush_wal/2` if
   supported by `rust-rocksdb 0.51`; schedule it on `DirtyIo` and distinguish
   synchronous from non-synchronous flush behavior.
6. **Phase 2.6 — Crash-process tests:** Add separate-process/BEAM tests proving
   durable dirty/data/clean checkpoint sequences survive forced writer-process
   termination and reopen with no clean marker ahead of its data.
7. **Phase 2.7 — Gate and commit:** Run compatibility, atomicity, durability,
   WAL, column-family, and complete regression tests; commit durable writes.

### EPIC002 acceptance evidence

- `write_batch/2` passes all legacy tests unchanged.
- `write_batch/3` exposes `sync` and WAL selection explicitly.
- Synchronous acknowledgement is tested through process termination and reopen.
- Contradictory durability options fail visibly.
- The implementation and docs do not claim deterministic loss for
  non-synchronous writes; only their weaker guarantee is documented.

## EPIC003 — Bounded Bulk Iteration

**Goal:** Provide efficient, bounded scans that preserve one iterator's view and
avoid one NIF transition per key/value pair.

1. **Phase 3.1 — Iterator-take contract:** Finalize `max_entries`, optional
   `max_bytes`, hard native limits, progress behavior, result ordering, and
   `:more`/`:end_of_iterator` status semantics.
2. **Phase 3.2 — Native extraction loop:** Implement `iterator_take/2` against
   `IteratorResource`, retaining the iterator lock for one bounded extraction
   and returning ordered binary key/value pairs.
3. **Phase 3.3 — Memory bounds:** Enforce entry and payload-byte limits before
   allocating unbounded native or BEAM results; return one oversized first item
   so repeated calls cannot stall.
4. **Phase 3.4 — Iterator coverage:** Prove the implementation works with
   standard, range, prefix, reverse, column-family, snapshot, and snapshot-CF
   iterator resources.
5. **Phase 3.5 — Continuation correctness:** Verify repeated calls emit every
   row exactly once, preserve iterator position, retain snapshot stability, and
   handle exact-boundary exhaustion without inventing a second terminal atom.
6. **Phase 3.6 — Throughput benchmark:** Compare `next/1` and
   `iterator_take/2` over representative key/value sizes, warm and cold scans,
   multiple batch limits, and one stable snapshot.
7. **Phase 3.7 — Gate and commit:** Run iterator, snapshot, CF, memory-bound,
   benchmark smoke, and complete tests; commit bounded iteration.

### EPIC003 acceptance evidence

- Large scans are bounded by caller options and native hard limits.
- No stateless reseek is used between pages.
- Snapshot iterator pages remain point-in-time consistent.
- Arbitrary binary keys and values round-trip unchanged.
- `next/1` remains compatible.

## EPIC004 — BEAM Scheduler Isolation

**Goal:** Ensure RocksDB cache state, file I/O, native locks, and iteration do
not unpredictably block normal BEAM schedulers.

1. **Phase 4.1 — NIF scheduler classification:** Classify every exported NIF as
   non-blocking metadata, potentially blocking I/O, or CPU-heavy work; record
   the reason and selected scheduler for each operation.
2. **Phase 4.2 — Point-operation migration:** Move default and column-family
   get/put/delete/merge operations that may touch RocksDB storage to `DirtyIo`.
3. **Phase 4.3 — Bulk-operation migration:** Move multi-get, existence checks
   where appropriate, WAL flush, and remaining storage-backed bulk operations
   to the selected safe scheduler.
4. **Phase 4.4 — Iterator and snapshot migration:** Move iterator creation,
   `next/1`, `iterator_take/2`, snapshot reads, snapshot multi-get, and snapshot
   iterator creation to `DirtyIo`.
5. **Phase 4.5 — Lifecycle and metadata audit:** Verify open, close, repair,
   destroy, CF lifecycle, checkpoint, backup, restore, and sequence/path metadata
   functions use an appropriate scheduler without unnecessary migration.
6. **Phase 4.6 — Responsiveness benchmark:** Measure hot throughput, cold-read
   latency, scan throughput, dirty-scheduler saturation, and independent BEAM
   heartbeat latency while RocksDB work runs.
7. **Phase 4.7 — Gate and commit:** Resolve unacceptable scheduler regressions,
   retain functional parity, publish benchmark context, run the complete gate,
   and commit scheduler isolation.

### EPIC004 acceptance evidence

- No operation capable of blocking on storage remains on a normal scheduler
  without an explicit written justification.
- Scheduler-responsiveness tests measure unrelated BEAM process latency.
- Benchmarks report both database throughput and VM responsiveness.
- Dirty scheduling does not change storage return values.

## EPIC005 — Safe Explicit Database Closure

**Goal:** Add deterministic close/reopen behavior without invalidating live
native iterators or snapshots.

1. **Phase 5.1 — Closable database state:** Refactor `DbResource` from
   `RwLock<DB>` to an explicitly open/closed state such as
   `RwLock<Option<DB>>`; centralize access helpers that return `:closed` rather
   than unwrapping or panicking.
2. **Phase 5.2 — Dependency lease model:** Add race-safe accounting for native
   children and define when regular iterators, snapshots, and snapshot iterators
   acquire and release database-lifetime leases.
3. **Phase 5.3 — Iterator lifecycle:** Integrate regular and CF iterators with
   lease accounting, including destructor behavior and failed-construction
   cleanup.
4. **Phase 5.4 — Snapshot lifecycle:** Integrate snapshots and nested snapshot
   iterators without double-counting or prematurely releasing the database
   lease retained by the snapshot owner.
5. **Phase 5.5 — `close/1`:** Acquire exclusive database state, return
   `:resource_busy` when children exist, drop RocksDB before success, make
   repeated close idempotent, and return `:closed` from subsequent operations.
6. **Phase 5.6 — Race and path-lock tests:** Repeatedly test concurrent
   close/operation/child creation, process exits, immediate reopen, immediate
   destroy, active-child rejection, deadlock absence, and garbage-collection
   fallback; run native sanitizers where supported.
7. **Phase 5.7 — Gate and commit:** Complete lifecycle review, run stress and
   regression tests, verify no use-after-free path, and commit explicit close.

### EPIC005 acceptance evidence

- Successful close releases the RocksDB path lock before returning.
- Close cannot succeed while a dependent resource can access RocksDB.
- Operations after close return stable errors.
- A second close succeeds idempotently.
- Existing resource-GC behavior remains safe.
- Native stress tests show no panic, deadlock, or memory-safety failure.

## EPIC006 — Exact Configuration And Documentation

**Goal:** Make accepted options, validation, examples, errors, and operational
semantics exact enough that production behavior cannot differ silently from
operator intent.

1. **Phase 6.1 — Canonical option inventory:** Define one authoritative inventory
   for database, read, write, and iterator options, including accepted types,
   defaults, native mapping, documentation status, and compatibility aliases.
2. **Phase 6.2 — Unknown-option rejection:** Change native decoders to reject
   unknown keys with structured errors and add explicit coverage for misspelled
   WAL, durability, direct-I/O, compression, and compaction options.
3. **Phase 6.3 — Type and combination validation:** Reject invalid option value
   types and incompatible combinations before mutating or opening a database;
   ensure errors identify the option rather than exposing an opaque badarg.
4. **Phase 6.4 — Reference documentation:** Update README, cheatsheet, module
   docs, changelog draft, and examples for exact option names, durability levels,
   iterator statuses, bulk bounds, dirty scheduling, close behavior, and errors.
5. **Phase 6.5 — Executable examples:** Add CI checks or focused tests that run
   representative documented examples, preventing future drift between docs,
   Elixir stubs, and Rust decoders.
6. **Phase 6.6 — 0.5.0 migration guidance:** Document the unknown-option behavior
   change, how to audit existing configurations, on-disk compatibility, rollback
   constraints, and how to select synchronous checkpoint writes.
7. **Phase 6.7 — Gate and commit:** Run option inventory checks, documentation
   examples, compatibility tests, and the complete gate; commit exact
   configuration behavior.

### EPIC006 acceptance evidence

- Every documented option is accepted.
- Every accepted public option is documented or explicitly designated internal.
- Unknown and misspelled options fail visibly.
- The documentation uses only `:end_of_iterator`.
- Durability examples distinguish `sync`, WAL enablement, and `set_use_fsync`.
- Existing databases open without migration.

## EPIC007 — Failure Verification And Release Readiness

**Goal:** Validate the complete consistency model under realistic failures,
measure its operational costs, and prepare trustworthy 0.5.0 artifacts.

1. **Phase 7.1 — End-to-end checkpoint protocol:** Build a representative
   durable dirty/data/clean materialization flow using `write_batch/3`, reopen it
   across process boundaries, and prove that a clean cursor never authorizes
   missing data under the tested failure model.
2. **Phase 7.2 — Failure matrix:** Exercise termination before dirty, after
   dirty, during data writes, before clean, after clean, during close, and while
   iterator/snapshot children exist; classify every expected recovery action.
3. **Phase 7.3 — Concurrency and native stress:** Run repeated concurrent
   readers, writers, bulk iterators, snapshots, close attempts, CF operations,
   and path reopen cycles; use sanitizers and platform tools where supported.
4. **Phase 7.4 — Comparative benchmarks:** Publish 0.4.1-baseline versus 0.5.0
   results for point throughput, synchronous and non-synchronous batch writes,
   bulk iteration, memory returned per page, close latency, and BEAM heartbeat
   latency.
5. **Phase 7.5 — Precompiled artifact matrix:** Build and smoke-test every
   supported NIF target: Apple ARM64/x86-64, Linux ARM64/x86-64 glibc and musl,
   and Windows x86-64; verify checksums and that new public arities bind correctly.
6. **Phase 7.6 — Package and release preparation:** Update versions, package
   contents, changelog, README, cheatsheet, ADR status, upgrade notes, release
   workflow, checksums, and source-build requirements without publishing early.
7. **Phase 7.7 — Final gate and commit:** Run all formatting, source build,
   warnings-as-errors, full tests, crash tests, stress tests, benchmark smoke,
   package inspection, and precompiled-NIF smoke tests; commit the completed
   roadmap and only then authorize the 0.5.0 tag/release.

### EPIC007 acceptance evidence

- The durability protocol is tested across independent OS/BEAM process lifetime.
- The complete failure matrix has deterministic expected recovery behavior.
- Resource races produce no panic, deadlock, or invalid native access.
- Scheduler responsiveness is measured under storage load.
- All supported precompiled targets expose the new APIs.
- Upgrade and rollback guidance is complete before release.

---

## Cross-Epic Invariants

These invariants apply after every epic:

1. Existing database files remain readable.
2. No existing key/value bytes are rewritten merely by opening a database.
3. Existing operation tuples preserve their meaning.
4. `write_batch/2` remains the default non-synchronous WAL-enabled path.
5. `:end_of_iterator` remains the sole iterator terminal atom.
6. New errors are stable and programmatic; RocksDB strings remain diagnostic.
7. Every resource operation handles closed/unavailable state without panic.
8. Tests use unique temporary paths and release resources deterministically.
9. The source-built NIF, not a stale precompiled artifact, is used for native
   implementation validation.
10. Performance results include hardware, operating system, data size, options,
    warm/cold state, and concurrency.

## Required Test Layers

### Elixir API tests

- New arities and default delegation.
- Stable return and error shapes.
- Option validation.
- Existing API compatibility.
- Documentation examples.

### Native functional tests

- RocksDB write options.
- WAL flush behavior.
- Iterator bounds and continuation.
- Open/closed state.
- Resource lease transitions.

### Process-boundary tests

- Writer process termination.
- Database reopen.
- Path lock release.
- Dirty/clean checkpoint recovery.

### Concurrency tests

- Simultaneous independent reads/writes.
- Same-database iterator and writer behavior.
- Close racing with operation and child creation.
- Snapshot retention.
- Repeated resource destruction.

### Performance tests

- Point get/put/delete.
- Default and synchronous batches.
- `next/1` versus `iterator_take/2`.
- Warm and cold scans.
- BEAM scheduler heartbeat latency.
- Memory and payload bounds.

### Release tests

- Forced source compilation.
- Precompiled NIF loading.
- Public function binding inventory.
- Package file inclusion.
- Supported platform smoke tests.

## Non-Goals

ROADMAP002 does not include:

- A new database abstraction or OTP supervision framework.
- Distributed RocksDB replication.
- Cross-database transactions.
- Automatic application-level checkpoint protocols.
- Changing existing merge-operator semantics.
- Changing RocksDB's on-disk format.
- Replacing binary keys or values with an ExRocket serialization format.
- Guaranteeing survival against storage hardware that violates acknowledged
  flush semantics.
- Making every write synchronous by default.
- Publishing the release before all final gates pass.

## Definition Of Done

ROADMAP002 is complete when:

- All seven epics and all forty-nine phases are complete.
- Seven independently green epic commits exist.
- `write_batch/3` provides validated RocksDB write options.
- Existing `write_batch/2` behavior remains compatible.
- Trusted checkpoints can use synchronous WAL durability boundaries.
- `iterator_take/2` provides bounded, consistent iterator advancement.
- Potentially blocking RocksDB calls use appropriate dirty scheduling.
- `close/1` safely releases the database and rejects active native children.
- Post-close operations return stable errors without panics.
- Unknown options fail visibly.
- Documentation exactly matches iterator and option behavior.
- Full source-build, crash, stress, benchmark, and artifact gates pass.
- Existing RocksDB databases require no migration.
- ADR002 is updated from Proposed to Accepted and implemented.
- The 0.5.0 release is prepared and authorized for tagging.

## Planned Commit Sequence

```text
roadmap002 - epic 1 - establish consistency contracts
roadmap002 - epic 2 - add durable write boundaries
roadmap002 - epic 3 - add bounded bulk iteration
roadmap002 - epic 4 - isolate RocksDB NIF scheduling
roadmap002 - epic 5 - add safe explicit close
roadmap002 - epic 6 - enforce exact configuration
roadmap002 - epic 7 - complete failure and release verification
```

## Completion Record

This section remains empty until implementation begins. Each epic must append:

- Commit hash.
- Validation command and result.
- Test count.
- Relevant benchmark or stress-test evidence.
- Any ADR amendment made during implementation.
