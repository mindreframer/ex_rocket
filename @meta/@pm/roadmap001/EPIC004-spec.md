# EPIC004 Spec: Column Families

## Purpose

Reach complete column-family functionality on the maintained backend.

## Scope

CF lifecycle/opening, KV operations, helper reads, batch operations, range deletion, multi-get, existence checks, and iteration.

## Acceptance Criteria

- CF names are resolved safely without panics.
- Unknown CF behavior matches the existing API.
- Writable and read-only multi-CF opens work.
- All CF data operations and iterators pass parity tests.

## Test Strategy

Run the existing CF behavioral scenarios against `ExRocket.RustRocksDB` using isolated directories.

## Quality Gate

Compile both crates and run focused and full tests before commit.
