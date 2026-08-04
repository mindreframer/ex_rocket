# EPIC005 Spec: Safe Explicit Database Closure

## Purpose

Add deterministic close/reopen behavior without invalidating live native iterators or snapshots.

## Scope

Closable database state; dependent-resource leases; centralized closed-state access; iterator/snapshot lifecycle integration; `close/1`; path-lock and race tests.

## Out Of Scope

Forced child invalidation, indefinite waits for children, or a supervised OTP database owner.

## Acceptance Criteria

- `close/1` has the contract `@spec close(db()) :: :ok | {:error, :resource_busy | term()}`, runs on `DirtyIo`, drops RocksDB before returning `:ok`, and is idempotent.
- Successful close releases the path lock and permits immediate reopen or destroy.
- Every operation using a closed database resource returns `{:error, :closed}` without panic.
- Close returns `{:error, :resource_busy}` while a regular iterator or snapshot owns a database lease.
- Snapshot iterators retain their snapshot owner without double-counting the database lease.
- Exclusive database state prevents child creation from racing between the busy check and database removal.
- Concurrent close/operation/child creation completes without deadlock, panic, or use-after-free.
- GC-based closure remains safe when explicit close is omitted, and writable/read-only/default-CF/multi-CF resources share the contract.

## Test Strategy

Cover immediate/repeated close, all post-close operations, every child type, process exits, immediate path reuse, repeated races, GC fallback, and native sanitizers where supported.

## Quality Gate

Run the roadmap source gate, lifecycle tests, repeated native race stress, and sanitizer checks where the supported toolchain permits them before commit.
