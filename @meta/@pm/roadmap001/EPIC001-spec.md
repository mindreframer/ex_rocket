# EPIC001 Spec: Parallel Backend Foundation

## Purpose

Create an independently loadable Elixir module and Rust NIF crate using the maintained `rust-rocksdb` package while leaving `ExRocket` and `native/rocker` unchanged.

## Scope

- Pin and document maintained dependency versions.
- Add `native/rocker_maintained`.
- Add `ExRocket.RustRocksDB`.
- Register independent resources and implement `lxcode/0`.
- Add dual-load smoke tests.

## Out Of Scope

Database operations beyond NIF loading and backend identification.

## Acceptance Criteria

- Both NIF modules compile and load in one BEAM runtime.
- `ExRocket.lxcode/0` remains unchanged.
- `ExRocket.RustRocksDB.lxcode/0` identifies the maintained backend.
- Existing tests stay green.

## Test Strategy

Compile both crates from source and run focused loading tests followed by the full ExUnit suite.

## Quality Gate

Run formatting, `FORCE_BUILD=yes mix compile`, and `FORCE_BUILD=yes mix test`; commit only when green.
