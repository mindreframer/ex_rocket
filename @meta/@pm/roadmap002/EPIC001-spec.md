# EPIC001 Spec: Contract Baseline And Validation Harness

## Purpose

Freeze current behavior and ADR002 public contracts before changing native behavior, correct known documentation drift, and establish a repeatable source-built validation gate.

## Scope

Public API/NIF/scheduler/resource/option inventory; behavioral baseline tests; types, specs, and stubs for new APIs; stable error vocabulary; immediate documentation corrections; `scripts/roadmap002_check.sh`.

## Out Of Scope

Native implementations of durable writes, bulk iteration, or explicit close.

## Acceptance Criteria

- Every public function/arity, NIF export, scheduler class, dependent resource, option decoder, and relevant return shape is captured.
- Focused tests protect current batch, iterator, snapshot, path-lock, GC-closure, option, and terminal-atom behavior.
- `write_batch/3`, `iterator_take/2`, and `close/1` have exact documented contracts, types, specs, and NIF stubs.
- `flush_wal/2` is included only after confirming the exact `rust-rocksdb 0.51` API; otherwise its omission is documented.
- Stable programmatic conditions are defined for closed/busy resources, invalid new option maps, and unknown keys.
- Documentation uses `:end_of_iterator`, canonical native option names, and distinguishes atomicity from synchronous durability.
- The source-built roadmap validation script passes from a clean build with the existing suite green.

## Test Strategy

Add API inventory and focused baseline regressions before native refactoring, then run the clean forced-source-build gate.

## Quality Gate

Run Elixir and Rust formatting, `FORCE_BUILD=yes` compilation with warnings as errors, and the complete ExUnit suite before commit.
