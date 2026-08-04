# EPIC002 Spec: Durable Write Boundaries

## Purpose

Expose RocksDB write durability without changing existing `write_batch/2` defaults or atomicity.

## Scope

Dedicated write-option decoding; `write_batch/3`; compatibility delegation; validation; conditional `flush_wal/2`; process-boundary durability tests.

## Out Of Scope

Write-option arities for point or column-family convenience operations.

## Acceptance Criteria

- `write_batch/3` returns `{:ok, non_neg_integer()}` or `{:error, term()}` and applies `%{sync: false, disable_wal: false}` by default through `DB::write_opt`.
- Existing default and column-family batch tuples retain ordering, atomicity, and operation counts.
- `write_batch/2` delegates to the exact default-options path and passes legacy tests unchanged.
- Unknown keys return `{:error, {:unknown_option, key}}`; non-booleans and `%{sync: true, disable_wal: true}` return `{:error, :invalid_write_options}` before mutation.
- `%{sync: true}` reaches RocksDB with WAL enabled; WAL-disabled mode is available only by explicit request.
- If supported by the exact API confirmed in EPIC001, `flush_wal/2` returns `:ok | {:error, term()}`, preserves RocksDB's native sync semantics, runs on `DirtyIo`, and documents synchronous/non-synchronous behavior.
- An independent OS process or BEAM instance proves acknowledged dirty/data/clean sequences survive forced writer termination and that a clean cursor never authorizes missing projection data under the tested failure model.

## Test Strategy

Cover defaults, sync and WAL-disabled modes, invalid options, default/CF batches, atomic validation failure, conditional WAL flush, and terminate/reopen checkpoint scenarios.

## Quality Gate

Run the roadmap source gate plus focused compatibility, atomicity, durability, WAL, and column-family tests before commit.
