# ADR001: Upgrade To The Maintained rust-rocksdb Crate

- **Status:** Accepted and implemented
- **Date:** 2026-07-27
- **Decision owners:** ExRocket maintainers

## Context

ExRocket's original native backend uses the `rocksdb` Rust crate version 0.24,
which bundles RocksDB 10.4.2. That Rust package is no longer receiving the
updates needed by this project and is unlikely to track current RocksDB
releases.

A parallel backend was implemented with the maintained `rust-rocksdb` package
version 0.51, bundling RocksDB 11.1.2. It is exposed during validation as
`ExRocket.RustRocksDB` and has an independent `native/rocker_maintained` NIF
crate. Keeping both implementations temporarily allowed the existing backend to
remain untouched while the maintained backend acquired the complete ExRocket
API.

Validation established the following:

- `ExRocket` and `ExRocket.RustRocksDB` expose the same 64 public function
  names and arities.
- The full ExUnit suite passes alongside 50 maintained-backend-specific tests.
- Core KV, batches, iterators, column families, snapshots, checkpoints,
  backups, options, and all existing merge operators work through the
  maintained backend.
- A bidirectional high-level database check passes for representative data:
  RocksDB 10.4.2 writes are readable by RocksDB 11.1.2, and RocksDB 11.1.2
  writes are readable by RocksDB 10.4.2.
- Comparative local benchmarks show effectively equivalent reads and a modest
  write improvement for the maintained backend.

Maintaining both native implementations permanently would duplicate native
code, build graphs, release artifacts, CI jobs, maintenance effort, and runtime
payload. The project does not promise strict backward compatibility, and exact
RocksDB error strings or obscure option behavior are not part of the migration
requirement.

## Decision

Adopt `rust-rocksdb` as ExRocket's only RocksDB Rust binding.

The transition will be made in explicit, independently validated phases:

1. Keep both native crates present, but route the public `ExRocket` module to
   `ExRocket.RustRocksDB` through Elixir delegation.
2. Run the complete existing legacy test suite unchanged. This makes the old
   tests exercise the maintained native backend and proves that the established
   `ExRocket` API works on it.
3. Resolve only meaningful API-level incompatibilities found by those tests.
   Backend identification may be adapted by the public facade; RocksDB-version
   error text is not required to remain identical.
4. Remove the unmaintained native crate, its Cargo dependency graph, duplicate
   build/release jobs, and obsolete dual-backend comparison tooling.
5. Retain `ExRocket` as the primary public API. Retain
   `ExRocket.RustRocksDB` as an explicit alias-compatible module backed by the
   same single maintained NIF.

## Compatibility Position

The bidirectional database-format check is evidence of practical compatibility,
not a blanket guarantee. It covers binary values, Unicode, empty and larger
values, Erlang external terms, batches, deletions, column families, and CF
batches. It does not guarantee every historical SST format, option combination,
merge-operator state, future RocksDB version, or downgrade path.

Production upgrades should retain backups and test representative data. This
project relies primarily on RocksDB's own compatibility guarantees and the
maintained Rust wrapper's test suite rather than duplicating their exhaustive
coverage.

## Consequences

### Positive

- One maintained RocksDB binding and one native implementation.
- Current RocksDB fixes and features become accessible through an actively
  maintained wrapper.
- Existing callers continue using the `ExRocket` module and API.
- Legacy ExUnit tests become regression tests for the maintained backend.
- Native artifact size, build cache, CI matrix, and maintenance work return to
  a single-backend model.

### Negative

- Source builds require Rust 1.91 or newer for the selected wrapper release.
- Exact RocksDB error messages may change.
- The removed RocksDB 11 option
  `set_skip_checking_sst_file_sizes_on_db_open` remains only a compatibility
  no-op.
- A downgrade to the removed native implementation will no longer be available
  in the normal package.

## Rejected Alternatives

### Keep both backends indefinitely

Rejected because it doubles native maintenance and release complexity without a
long-term product requirement.

### Keep the legacy backend as the default

Rejected because its Rust binding is not maintained at the cadence required by
this project.

### Rewrite the NIF against the RocksDB C API directly

Rejected because it would duplicate substantial work already maintained and
tested by `rust-rocksdb`.

## Implementation Outcome

The existing ExRocket suite passed unchanged after `ExRocket` was routed through
the maintained backend. The unmaintained native implementation was then removed.
The maintained crate now occupies the canonical `native/rocker` path and produces
the canonical `rocker` artifact. `ExRocket` remains the primary facade, while
`ExRocket.RustRocksDB` is the single NIF-owning module.

## Verification Required Before Legacy Removal

- The unchanged legacy ExUnit files pass while `ExRocket` delegates to the
  maintained backend.
- Maintained-specific tests continue to pass.
- Public function name/arity parity remains exact.
- The bidirectional on-disk compatibility script remains green before the old
  native crate is deleted.
