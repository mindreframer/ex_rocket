# EPIC003 Spec: Bounded Bulk Iteration

## Purpose

Provide efficient bounded scans that preserve one iterator view and avoid one NIF transition per key/value pair.

## Scope

`iterator_take/2`; `max_entries`; optional `max_bytes`; hard native limits; progress and status semantics; all iterator resource variants; throughput benchmarks.

## Out Of Scope

Stateless pagination, automatic snapshots, or unbounded range collection.

## Acceptance Criteria

- `iterator_take/2` returns `{:ok, [{binary(), binary()}], :more | :end_of_iterator}` or `{:error, term()}`.
- `max_entries` is required and positive; both bounds are validated and constrained by documented native hard limits.
- Unknown keys return `{:error, {:unknown_option, key}}`; malformed bounds return `{:error, :invalid_iterator_options}` without advancing.
- Iteration stops at a bound or observed exhaustion, and one oversized first entry is returned so every call can progress.
- Bound-first calls return `:more`; only observed exhaustion returns `:end_of_iterator`; no look-ahead row is consumed.
- Repeated calls emit every row exactly once without reopen/reseek across standard, range, prefix, reverse, CF, snapshot, and snapshot-CF iterators.
- Arbitrary binaries round-trip unchanged, snapshot pages remain stable, and `next/1` remains compatible.

## Test Strategy

Cover empty and exact boundaries, over-limit pages, oversized rows, directions/ranges/prefixes, all owners, repeated continuation, invalid options, snapshot stability, and benchmark smoke.

## Quality Gate

Run the roadmap source gate, iterator/snapshot/CF tests, memory-bound checks, and comparative scan benchmark smoke before commit.
