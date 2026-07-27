# EPIC003 Spec: Batches And Read Primitives

## Purpose

Add efficient bulk mutation and traversal primitives to the maintained backend.

## Scope

Default-CF write batches, range delete, multi-get, existence checks, iterator resources, full/range/prefix iteration, and iterator advancement.

## Acceptance Criteria

- Batch operations are atomic from the caller perspective.
- Multi-get ordering and missing-key behavior match the legacy module.
- Iterators retain valid database ownership and return `:end_of_iterator` correctly.
- Range and prefix boundaries match existing tests.

## Test Strategy

Port focused batch and iterator cases to the maintained module and retain all legacy tests.

## Quality Gate

Run formatting, native compilation, focused tests, and full tests before commit.
