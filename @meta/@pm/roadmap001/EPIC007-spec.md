# EPIC007 Spec: API Parity, Benchmarks, And Release Readiness

## Purpose

Finish the maintained backend, prove public API coverage, compare both implementations, and document how to build and ship them.

## Scope

Mechanical API inventory, dual-backend behavioral tests, error/resource/concurrency tests, comparative benchmarks, CI/release wiring, and user/developer documentation.

## Acceptance Criteria

- Every public `ExRocket` function name/arity exists on `ExRocket.RustRocksDB`.
- Both complete functional suites pass.
- Benchmarks execute equivalent workloads for both modules.
- CI can source-build the maintained backend.
- Release artifact names cannot collide.
- Selection, limitations, and rollback are documented.

## Test Strategy

Use API introspection, shared behavior tests, complete ExUnit runs, and benchmark smoke execution.

## Quality Gate

Run formatter, both native builds, all tests, API parity checks, and benchmark smoke before final commit.
