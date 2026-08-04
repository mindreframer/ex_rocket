# ROADMAP002 Lifecycle QA Record

## EPIC005

**Date:** 2026-08-04

The explicit-close implementation was validated with:

- The complete clean source-build gate: 113 ExUnit tests.
- Five repeated `test/close_test.exs` runs.
- Fifty concurrent child-creation/close races per run (250 total in the repeated
  gate), accepting only the two linearizable outcomes:
  - child created and close returned `{:error, :resource_busy}`;
  - close succeeded and child creation returned `{:error, :closed}`.
- Regular iterator, snapshot, and nested snapshot-iterator lease release.
- Failed child construction without a leaked lease.
- Immediate same-path reopen and destroy.
- Writable, read-only, and multi-column-family handles.
- Every public operation taking a database resource after close.
- Existing process-exit/GC closure tests.
- `cargo check` with Rust 1.91.0.

## Sanitizer Availability

The pinned stable Rust 1.91 toolchain does not expose Rust AddressSanitizer via
stable compiler flags, and the bundled RocksDB C++ library plus Rustler NIF must
be rebuilt with matching instrumentation for a valid sanitizer result. No such
supported sanitizer target exists in the current project/CI matrix, so the
sanitizer gate is recorded as a platform/toolchain skip rather than presenting
an uninstrumented run as evidence. Repeated race testing remains mandatory on
all supported source builds.
