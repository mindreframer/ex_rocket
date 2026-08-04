# EPIC004 Spec: BEAM Scheduler Isolation

## Purpose

Ensure RocksDB cache state, file I/O, and native locks do not unpredictably block normal BEAM schedulers.

## Scope

Complete exported-NIF scheduler classification; `DirtyIo` migration for potentially blocking point, bulk, iterator, snapshot, lifecycle, and metadata operations; responsiveness benchmarks.

## Out Of Scope

Telemetry, `DirtyCpu` work, or changes to storage return values.

## Acceptance Criteria

- Every exported NIF has a recorded blocking classification, selected scheduler, and rationale.
- No operation capable of blocking on storage or a native lock remains on a normal scheduler without explicit written justification.
- Point and CF operations, storage-backed bulk operations, iterator creation, `next/1`, `iterator_take/2`, snapshot reads/iterators, and relevant lifecycle/metadata operations run on `DirtyIo`.
- Operations already scheduled as dirty I/O remain so, and demonstrably non-blocking metadata avoids unnecessary migration.
- Inventory regression coverage detects unclassified exported NIFs.
- Benchmarks report hot point throughput, cold latency, scan throughput, dirty-scheduler saturation, and independent BEAM heartbeat latency.
- Functional return values and the full suite remain unchanged.

## Test Strategy

Combine scheduler-inventory checks, focused functional parity, cold or sufficiently large storage stress, independent heartbeat sampling, and benchmark smoke.

## Quality Gate

Run the roadmap source gate, scheduling regressions, responsiveness stress, and comparative benchmark smoke before commit.
