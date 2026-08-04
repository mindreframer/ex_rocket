# EPIC007 Spec: Failure Verification And Release Readiness

## Purpose

Validate the complete consistency model under realistic failures, measure its operational costs, and prepare trustworthy ExRocket 0.5.0 artifacts.

## Scope

End-to-end checkpoint protocol; failure matrix; concurrency/native stress; comparative benchmarks; precompiled target matrix; package, release, upgrade, and rollback preparation.

## Out Of Scope

Publishing or tagging the release before every final gate passes.

## Acceptance Criteria

- A representative dirty/data/clean materialization flow proves that a clean cursor never authorizes missing data across independent OS/BEAM process lifetime.
- Failures before/after dirty, during data, before/after clean, during close, and with live children have deterministic expected recovery actions.
- Repeated mixed-operation stress produces no panic, deadlock, or invalid native access; supported sanitizer runs are green or have an explicit platform skip record.
- Published 0.4.1-versus-0.5.0 results cover point throughput, sync/non-sync batches, bulk iteration, page memory/payload, close latency, and BEAM heartbeat latency, recording hardware, OS, data size, options, warm/cold state, and concurrency.
- Apple ARM64/x86-64, Linux ARM64/x86-64 for glibc and musl, and Windows x86-64 artifacts build, load, pass checksum checks, and bind all new arities; conditional `flush_wal/2` is included when EPIC001 confirms API support.
- Package contents, versions, changelog, docs, ADR status, upgrade/rollback notes, workflow, checksums, and source-build requirements are ready.
- 0.5.0 is not authorized for tagging until all source, crash, stress, benchmark-smoke, package, and precompiled-NIF gates pass.

## Test Strategy

Run the complete failure matrix, source suite, race stress, supported sanitizers, comparative benchmark smoke, package inspection, and all-platform artifact smoke tests.

## Quality Gate

Require every functional, failure, platform, artifact, documentation, and release gate to pass before the final epic commit and release authorization.
