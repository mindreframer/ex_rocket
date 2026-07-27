# EPIC006 Spec: Merge Operators And Full Options

## Purpose

Match ExRocket merge semantics and its practical option-decoding surface on maintained rust-rocksdb.

## Scope

Default and CF merges, binary-term helpers, counter/Erlang-term/bitset operators, DB options, table/cache/compression/compaction settings, and read options.

## Acceptance Criteria

- Existing merge scenarios produce equivalent values.
- Existing valid option maps open successfully.
- Invalid option values return controlled errors rather than panics.
- Range iterator read options behave as before.

## Test Strategy

Port merge and option-heavy cases and compare both backends where deterministic.

## Quality Gate

Run formatting, both builds, merge/options tests, and all tests before commit.
