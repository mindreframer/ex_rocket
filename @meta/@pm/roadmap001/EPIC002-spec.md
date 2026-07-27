# EPIC002 Spec: Database Lifecycle And Core KV

## Purpose

Make the maintained backend useful for basic database ownership and key/value operations while preserving legacy return shapes.

## Scope

Option decoding needed for lifecycle calls; open/read-only/destroy/repair; path and sequence metadata; put/get/delete; binary-term helper.

## Acceptance Criteria

- New and existing databases open correctly.
- Read-only handles reject writes.
- KV results use `:ok`, `:undefined`, `{:ok, value}`, and `{:error, reason}` consistently with `ExRocket`.
- Lifecycle cleanup is deterministic in tests.

## Test Strategy

Use unique temporary directories and run equivalent lifecycle/KV assertions against the maintained module.

## Quality Gate

Run all maintained tests and the complete legacy suite before commit.
