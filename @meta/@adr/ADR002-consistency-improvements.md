# ADR002: Consistency, Durability, And Lifecycle Improvements

- **Status:** Proposed
- **Date:** 2026-08-04
- **Decision owners:** ExRocket maintainers
- **Target release:** Next backward-compatible feature release where possible; use a minor-version boundary for intentionally stricter option validation

## Context

ExRocket 0.4.1 provides a broad RocksDB 11.1.2 API through the maintained
`rust-rocksdb` package. It supports point operations, atomic write batches,
column families, iterators, snapshots, range deletion, checkpoints, backups,
and merge operators. The current API is sufficient for many cache and embedded
storage workloads.

A provider-backed projection workload exposed several places where the public
API does not yet let callers state or enforce the consistency guarantees they
need:

1. `write_batch/2` is atomic but does not expose RocksDB `WriteOptions`.
2. Callers cannot request a synchronous WAL write for a durable commit marker.
3. Iterators cross the NIF boundary once per entry and `next/1` runs on a normal
   BEAM scheduler.
4. Several RocksDB calls that can block on storage also run on normal BEAM
   schedulers.
5. Database lifetime is controlled only by garbage collection of the Rustler
   resource; there is no explicit `close/1`.
6. The iterator terminal value is implemented and tested as
   `:end_of_iterator`, but `CHEATSHEET.md` documents `:end_of_table`.
7. The documented database-option examples use names such as
   `max_open_files`, while the native decoder accepts canonical names such as
   `set_max_open_files`.
8. Unknown database option keys are silently ignored by the native decoder.

These issues are related. Together they determine whether a caller can build a
reliable local projection, detect interrupted materialization, avoid trusting a
partially durable checkpoint, cleanly rotate database paths, and scan large key
ranges without harming BEAM scheduler responsiveness.

This ADR defines the desired semantics and API additions. It does not change
RocksDB's data model or replace existing ExRocket operations.

## Existing Semantics

### Atomicity is not durability

The current function:

```elixir
ExRocket.write_batch(db, operations)
```

constructs a RocksDB `WriteBatch` and calls `DB::write`. All operations in the
batch are applied atomically: readers observe either the batch before the write
or the batch after the write. That is a valuable consistency guarantee.

Atomicity does not state when the write becomes durable against operating-system
or machine failure. With RocksDB's default write options, WAL records are
written without requesting a synchronous filesystem flush before success is
returned. The following distinctions therefore matter:

- A BEAM process crash normally leaves acknowledged WAL data available to the
  surviving operating system and a later database reopen.
- A whole-node crash, power loss, storage-controller failure, or kernel failure
  may lose recently acknowledged non-synchronous writes.
- A synchronous WAL write requests that RocksDB flush the WAL through the
  operating-system durability boundary before reporting success.
- Disabling the WAL has materially weaker recovery semantics and must not be
  confused with an optimization that preserves the same guarantees.

A projection can always be rebuilt from its command log. However, a projection
checkpoint marked `clean` is only trustworthy after a machine restart if every
projection write represented by that checkpoint is at least as durable as the
clean marker.

### NIF scheduling affects VM consistency of service

Rustler NIFs without an explicit dirty scheduler run on normal BEAM scheduler
threads. RocksDB calls are usually fast when data is cached, but they can block
on disk I/O, file-system locks, compaction pressure, table-cache misses, or large
result conversion.

In 0.4.1, open, repair, backup, checkpoint, batch write, and range deletion use
`DirtyIo`. Point reads and writes, multi-get, iterator creation, snapshot reads,
and `next/1` do not. A cold read or long sequence of iterator calls can therefore
consume normal scheduler time and increase unrelated process latency.

This is not a data corruption problem. It is an availability and latency
consistency problem: an embedded database workload should not unpredictably
block normal BEAM scheduling based on cache state.

### Resource lifetime is safe but not explicitly controllable

`DbResource` owns RocksDB inside a Rustler `ResourceArc`. Iterators and snapshots
retain an owner reference, which prevents RocksDB from being dropped while they
use native references whose lifetimes are extended inside the NIF.

When the final resource reference disappears, RocksDB is dropped and its
filesystem lock is released. Process ownership can make this deterministic: if
the raw database resource exists only on an owner process heap, terminating that
process releases the lock. The public API itself does not express that pattern,
and callers that retain a reference cannot explicitly close it.

An unsafe close implementation would be worse than no close. It must never drop
the database while a snapshot or iterator still references it.

## Decision

ExRocket will add explicit write durability, bounded iterator reads, safe
resource closure, consistent dirty-I/O scheduling, and exact API documentation.
Existing APIs will remain available and preserve their current default behavior
unless a stricter option-validation release is explicitly selected.

The work is divided into five coordinated decisions.

## Decision 1: Add Per-Write Durability Options

### Public API

Add `write_batch/3` while preserving `write_batch/2`:

```elixir
@type write_options :: %{
        optional(:sync) => boolean(),
        optional(:disable_wal) => boolean()
      }

@spec write_batch(db(), [batch_operation()], write_options()) ::
        {:ok, non_neg_integer()} | {:error, term()}

def write_batch(db, operations, write_options)

def write_batch(db, operations),
  do: write_batch(db, operations, %{})
```

Examples:

```elixir
# Existing behavior: atomic, WAL enabled, no synchronous flush requested.
{:ok, 2} =
  ExRocket.write_batch(db, [
    {:put, "projection/a", "value"},
    {:put, "projection/b", "value"}
  ])

# Atomic and synchronously durable before success is returned.
{:ok, 1} =
  ExRocket.write_batch(
    db,
    [{:put, "materialization/checkpoint", "clean:42"}],
    %{sync: true}
  )
```

The native implementation will decode a dedicated write-options structure,
construct `rocksdb::WriteOptions`, and call `DB::write_opt`.

### Defaults

The defaults must preserve 0.4.1 behavior:

```elixir
%{
  sync: false,
  disable_wal: false
}
```

Omitted options use those defaults. The existing `write_batch/2` remains source
and behavior compatible.

### Validation

The API must reject:

- Unknown option keys.
- Non-boolean values for `sync` or `disable_wal`.
- `%{sync: true, disable_wal: true}`.

The last combination is rejected because it suggests a durability guarantee
that cannot be provided without a WAL. Returning an explicit error is safer
than silently accepting a contradictory request.

### Optional WAL flush API

Add an explicit WAL flush operation if supported by the selected
`rust-rocksdb` API:

```elixir
@spec flush_wal(db(), boolean()) :: :ok | {:error, term()}
def flush_wal(db, sync)
```

`sync` has RocksDB's native meaning: when true, the operation requests a
synchronous flush. This function is useful for applications that intentionally
group multiple non-synchronous writes and establish a durability boundary
without adding another logical record.

`flush_wal/2` does not replace `write_batch/3`. A durable commit marker is easier
to reason about when the marker and durability boundary are one operation.

### Durable checkpoint protocol

The intended projection protocol is:

1. Write a `dirty` marker with `%{sync: true}`.
2. Apply one bounded group of projection updates with WAL enabled. These updates
   may use the default non-synchronous mode.
3. Write the corresponding `clean` checkpoint with `%{sync: true}`.
4. Advance the source cursor only after the clean write succeeds.

RocksDB orders writes to the same database. The final synchronous WAL write
establishes a durability boundary covering the earlier WAL records before the
clean marker.

The recovery outcomes are then explicit:

| Failure point | Durable state after reopen | Required action |
| --- | --- | --- |
| Before durable dirty marker | Previous clean checkpoint | Continue from previous checkpoint |
| After dirty, before clean | Dirty checkpoint | Reset/replay affected projection |
| During projection writes | Dirty checkpoint | Reset/replay affected projection |
| After clean write succeeds | Projection writes and clean cursor are durable | Continue after clean cursor |

This protocol requires WAL to remain enabled for all covered projection writes.

### Scope of write options

The first implementation adds durability options to batch writes because a
single put, delete, or merge can already be represented as a one-operation
batch. This keeps the public expansion small and gives consistency-sensitive
callers one canonical write path.

Convenience arities such as `put/4`, `delete/3`, or column-family equivalents
may be added later by delegating to the same native write-options implementation.
They are not required for the initial decision.

## Decision 2: Add Bounded Bulk Iterator Reads

### Motivation

The current iterator API performs one NIF call and one result allocation per
entry:

```elixir
{:ok, key, value} = ExRocket.next(iterator)
```

This is convenient for small scans but expensive for projection prefixes,
secondary indexes, exports, and verification. It also exposes normal scheduler
threads to storage latency on every `next/1` call.

A bulk operation should:

- Preserve the existing iterator's stable view.
- Avoid reopening or reseeking a range between pages.
- Bound memory returned in one NIF call.
- Reduce NIF transition overhead.
- Run on a dirty I/O scheduler.
- Work with standard, range, prefix, column-family, and snapshot iterators.

### Public API

Add:

```elixir
@type iterator_take_options :: %{
        required(:max_entries) => pos_integer(),
        optional(:max_bytes) => pos_integer()
      }

@type iterator_status :: :more | :end_of_iterator

@spec iterator_take(iterator(), iterator_take_options()) ::
        {:ok, [{binary(), binary()}], iterator_status()}
        | {:error, term()}

def iterator_take(iterator, options)
```

Example:

```elixir
{:ok, iterator} =
  ExRocket.iterator_range(
    db,
    {:from, "account/", :forward},
    "account/",
    "account0"
  )

{:ok, rows, status} =
  ExRocket.iterator_take(iterator, %{
    max_entries: 1_000,
    max_bytes: 4 * 1024 * 1024
  })
```

### Bounds

`max_entries` is mandatory and must be positive. The native implementation will
also enforce a project-defined hard upper limit to prevent accidentally asking
a NIF to construct an unbounded result.

`max_bytes` bounds the combined key/value payload copied into the result. If the
first available entry alone exceeds `max_bytes`, that one entry is returned so
the iterator always makes progress. The byte bound excludes normal Erlang term
overhead and is therefore an approximate process-memory bound, not an exact
heap-size promise.

Iteration stops when either bound is reached or the iterator is exhausted.

### Status semantics

- `:end_of_iterator` means exhaustion was observed during the call.
- `:more` means the bounds were reached before exhaustion was observed.
- If a call returns exactly the last `max_entries` entries, it may return
  `:more`; a subsequent call can return an empty list with
  `:end_of_iterator`. This avoids consuming and buffering an extra entry merely
  to determine status.

### Consistency semantics

`iterator_take/2` advances the supplied iterator resource. It therefore retains
the same RocksDB iterator view across calls. It is preferable to a stateless
`scan_range/5` cursor because repeated stateless scans can observe different
database states between pages.

Callers that require a point-in-time view should continue to create the iterator
from a snapshot. Callers using a normal RocksDB iterator receive RocksDB's
normal iterator consistency semantics.

### Existing `next/1`

`next/1` remains supported and continues to return one entry. It will be moved
to `DirtyIo`. Its terminal value remains `:end_of_iterator`; documentation will
be corrected rather than adding a second terminal atom.

## Decision 3: Move Potentially Blocking RocksDB Calls To Dirty I/O Schedulers

Every NIF that may perform RocksDB storage I/O, wait on a RocksDB lock, or walk
an iterator must run with `schedule = "DirtyIo"` unless measurement and code
inspection prove that it cannot block.

This includes at least:

- `put`, `get`, `delete`, and `merge`.
- Column-family point operations.
- `multi_get` and `multi_get_cf`.
- Iterator creation functions.
- `next` and the new `iterator_take`.
- Snapshot gets, snapshot multi-get, and snapshot iterator creation.
- `drop_cf` and other column-family metadata operations that can touch storage.
- `latest_sequence_number` only if implementation analysis shows it can wait;
  otherwise it may remain a normal NIF.

Operations already scheduled as dirty I/O remain so.

### Why not `DirtyCpu`

These functions wait on storage and native locks. They are not primarily
CPU-bound computations, so `DirtyIo` is the correct scheduler class.

### Performance consequence

Dirty scheduler dispatch adds overhead to very small hot-cache operations.
Correct BEAM scheduler isolation is more important than maximizing a synthetic
single-key NIF benchmark on normal schedulers. Benchmarks must separately report:

- Hot point-operation throughput.
- Cold or intentionally uncached latency.
- Bulk iterator throughput.
- Unrelated BEAM process latency while storage operations run.

The new bulk iterator operation should recover much of the transition overhead
for scan workloads.

## Decision 4: Add Safe, Explicit Database Closure

### Public API

Add:

```elixir
@spec close(db()) :: :ok | {:error, :resource_busy | term()}
def close(db)
```

The intended semantics are:

- `close/1` releases RocksDB files and the database lock before returning.
- A successful close allows the same path to be reopened or destroyed
  immediately.
- Closing an already closed database is idempotent and returns `:ok`.
- Operations attempted after close return `{:error, :closed}`.
- Close returns `{:error, :resource_busy}` while live iterators or snapshots
  depend on the database.
- Garbage-collection-based closure remains as a fallback when callers do not
  call `close/1`.

### Native resource design

The existing resource contains:

```rust
pub struct DbResource {
    db: RwLock<DB>,
}
```

A safe close requires an optional state and dependent-resource accounting. The
conceptual design is:

```rust
pub struct DbResource {
    db: RwLock<Option<DB>>,
    leases: AtomicUsize,
}
```

A regular iterator or snapshot acquires a lease before releasing the database
read lock used during its creation. Its resource destructor releases that lease.
A snapshot iterator keeps the snapshot alive and must not incorrectly count or
release the database lease twice.

`close/1` acquires the database write lock. While that lock is held, no new
iterator or snapshot can complete creation. It then:

1. Returns `:ok` if the database is already absent.
2. Returns `{:error, :resource_busy}` if dependent leases exist.
3. Takes the `DB` from the option.
4. Drops it before reporting success.

The write lock plus lease accounting closes the race between checking for
children and creating a new child resource.

### Why close must reject active children

Iterator and snapshot resources currently retain an owner `ResourceArc`, and
the native implementation extends RocksDB reference lifetimes inside those
resources. Dropping the underlying `DB` while they remain live would violate the
safety condition that the owner reference currently provides. `close/1` must
not invalidate an active native child.

Rejecting close is clearer and safer than silently waiting for arbitrary BEAM
processes to release children. Callers can drop iterator/snapshot references,
allow their owning processes to exit, or retry closure later.

### Process ownership remains recommended

An OTP owner process should still be the normal application pattern. The owner
keeps the raw database reference private and closes it during termination.
Explicit close adds deterministic behavior for tests, path rotation, temporary
databases, application shutdown, and callers that cannot enforce exclusive
process-heap ownership.

## Decision 5: Make Documentation And Option Validation Exact

### Iterator terminal value

The canonical terminal value is:

```elixir
:end_of_iterator
```

`CHEATSHEET.md` will be corrected. `:end_of_table` will not be introduced as an
alias because two terminal values make consumers less deterministic and the
existing implementation and tests already agree on `:end_of_iterator`.

### Database option names

Documentation must use the exact native decoder keys, including:

```elixir
%{
  set_max_open_files: 1_000,
  set_write_buffer_size: 64 * 1024 * 1024,
  set_target_file_size_base: 64 * 1024 * 1024,
  set_max_bytes_for_level_base: 256 * 1024 * 1024
}
```

Examples using `max_open_files`, `write_buffer_size`, or similarly shortened
names will be corrected unless those aliases are deliberately implemented and
tested.

### Unknown options

Silently ignoring an unknown database option is unsafe. A misspelled durability,
WAL, direct-I/O, or compaction option can make production behavior differ from
what the operator believes was configured.

The decoder will reject unknown keys and report the offending key. Because some
existing callers may rely on ignored keys, this stricter behavior should be
released at a documented minor-version boundary rather than silently included
in a patch release.

Option tests and generated/reference documentation must come from one canonical
set of accepted keys where practical. This reduces future drift between the
Rust decoder, Elixir documentation, and examples.

## Error Semantics

New consistency APIs should prefer stable atoms or structured values for
programmatic conditions:

- `:closed`
- `:resource_busy`
- `:invalid_write_options`
- `:invalid_iterator_options`
- `{:unknown_option, key}`

Native RocksDB failures may continue to include RocksDB error strings for
operator diagnostics. Callers should not need to parse those strings to detect
the new lifecycle and validation conditions.

Malformed NIF arguments must return a documented error where practical rather
than crashing the calling process with an opaque bad argument exception.

## Compatibility

### Preserved

- `write_batch/2` remains available with current defaults.
- Existing operation tuples remain unchanged.
- `next/1` remains available.
- The iterator terminal atom remains the already implemented
  `:end_of_iterator`.
- Resource garbage collection continues to close databases when explicit close
  is not used.
- Existing on-disk databases and values require no migration.
- No RocksDB format or column-family layout changes are introduced.

### Additive changes

- `write_batch/3`.
- `flush_wal/2`, if supported and accepted during implementation.
- `iterator_take/2`.
- `close/1`.
- Stable lifecycle and validation error values.

### Intentionally stricter change

Unknown database option keys will become errors. This is behaviorally stricter
and must be called out in the release notes.

### Performance-visible change

Moving point operations to dirty schedulers may reduce peak hot-key
microbenchmark numbers. The expected benefit is bounded impact on normal BEAM
scheduler latency under cold or contended storage conditions. Both dimensions
must be measured and published.

## Implementation Plan

### Phase 1: Freeze public contracts

- Add Elixir types and NIF stubs for the new APIs.
- Define exact success, error, and validation shapes.
- Correct iterator and option examples in documentation.
- Add API-level tests before native implementation where feasible.

### Phase 2: Write options and WAL durability

- Add a Rust `WriteOptions` decoder.
- Implement `write_batch/3` with `DB::write_opt`.
- Delegate `write_batch/2` to default options.
- Add `flush_wal/2` if available in `rust-rocksdb 0.51`.
- Add validation for contradictory and unknown write options.

### Phase 3: Bounded iterator reads

- Implement `iterator_take/2` against `IteratorResource`.
- Enforce entry and byte bounds natively.
- Preserve iterator position between calls.
- Cover standard, range, prefix, column-family, and snapshot iterators.
- Move `next/1` to `DirtyIo`.

### Phase 4: Scheduler audit

- Audit every exported NIF for storage access or potentially blocking locks.
- Move the identified operations to `DirtyIo`.
- Keep only demonstrably non-blocking metadata operations on normal schedulers.
- Measure scheduler responsiveness and hot-operation overhead.

### Phase 5: Safe close

- Refactor `DbResource` to an optional database state.
- Add dependent-resource lease accounting.
- Implement idempotent close and stable post-close errors.
- Verify all iterator and snapshot creation/teardown races.
- Ensure a successful close permits immediate reopen and destroy.

### Phase 6: Exact configuration validation

- Correct all public examples to canonical option names.
- Reject unknown database and read/write option keys.
- Add a canonical accepted-option inventory to reduce documentation drift.
- Document the stricter behavior in the changelog.

### Phase 7: Release verification

- Run the full ExUnit suite against source-built NIFs.
- Run durability and process-crash integration tests.
- Run scheduler responsiveness and throughput benchmarks.
- Build every precompiled release target.
- Smoke test the new APIs on macOS, glibc Linux, musl Linux, and Windows.
- Publish migration notes and examples before release.

## Verification Requirements

### Write durability

Tests must prove:

- `write_batch/2` retains existing behavior and operation counts.
- `write_batch/3` applies all operations atomically.
- `%{sync: true}` is accepted and uses the native synchronous write option.
- WAL-disabled writes are explicit.
- `sync: true` with `disable_wal: true` is rejected.
- Unknown keys and invalid values are rejected.
- Column-family batch operations receive the same write options.

A process-crash integration test should use a separate OS process or BEAM
instance:

1. Open a temporary database.
2. Write a durable dirty marker.
3. Write projection data.
4. Write a durable clean marker.
5. Terminate the writer without normal application cleanup.
6. Reopen from another process and verify marker/data consistency.

A test cannot deterministically prove that a non-synchronous write is lost on
power failure. The required proof is that synchronous options reach RocksDB's
`WriteOptions` and that acknowledged synchronous checkpoints survive forced
process termination and reopen.

### Bulk iteration

Tests must cover:

- Empty iterators.
- Fewer, equal, and more rows than `max_entries`.
- `max_bytes` boundaries.
- One entry larger than `max_bytes` still making progress.
- Arbitrary binary keys and values.
- Forward and reverse iteration.
- Range and prefix boundaries.
- Column-family iterators.
- Snapshot iterators remaining stable while the live database changes.
- Repeated calls returning every row exactly once.
- Invalid and excessively large bounds.

### Scheduler behavior

A stress test should run storage operations while independent BEAM processes
maintain short periodic deadlines. The result should report scheduler latency,
not only database throughput. The test should include cold or sufficiently large
data so it does not measure only block-cache hits.

### Explicit close

Tests must cover:

- Immediate close after open.
- Repeated close.
- Every operation after close.
- Immediate reopen of the same path after close.
- Immediate destroy after close.
- Close rejected with a live regular iterator.
- Close rejected with a live snapshot.
- Close rejected with snapshot iterators.
- Successful close after child resources are released.
- Concurrent child creation and close without use-after-free or deadlock.
- Garbage-collection closure still working when `close/1` is not called.

Native race tests should run repeatedly and under sanitizers where the Rustler
and RocksDB build permit it.

### Documentation and options

Tests or documentation checks must verify:

- Examples use `:end_of_iterator`.
- Every documented option is accepted.
- Every accepted option is either documented or intentionally marked internal.
- Unknown options fail visibly.
- The cheatsheet examples compile or execute in CI where practical.

## Operational Guidance

### Choosing durability

Use default writes when the database is disposable, rebuilding is cheap, and
losing the most recent writes after whole-node failure is acceptable.

Use `%{sync: true}` for:

- Materialization clean/dirty markers.
- Local transaction-log boundaries.
- Metadata that authorizes continuation after restart.
- Writes whose acknowledgement is interpreted as durable commit.

Do not set `disable_wal: true` for state that must survive a process crash before
memtable flush. WAL-disabled mode should be restricted to bulk-load workflows
that can restart from a known source.

### Choosing iteration APIs

Use `next/1` for small or interactive scans. Use `iterator_take/2` for exports,
prefix materialization, verification, and any scan where NIF transition overhead
or scheduler isolation matters.

Use snapshot iterators when all pages must represent one stable point in time.
A bounded bulk call controls transfer size; it does not by itself upgrade a live
iterator to snapshot isolation.

### Choosing lifecycle ownership

Prefer one OTP owner per database path. Keep the raw database resource private,
close it during orderly termination, and do not open the same RocksDB path from
multiple owners.

Treat `{:error, :resource_busy}` as a lifecycle bug or a signal to release known
iterators/snapshots before retrying. Do not force-close a database underneath
native children.

## Consequences

### Positive

- Callers can distinguish atomic acknowledgement from durable acknowledgement.
- Clean projection checkpoints can be made trustworthy across node failure.
- Large scans require far fewer NIF transitions.
- Storage latency no longer unpredictably blocks normal BEAM schedulers.
- Temporary and rotated database paths can be released deterministically.
- Iterator/snapshot safety is retained during explicit close.
- Documentation matches actual return values and accepted options.
- Misspelled production options fail visibly instead of being ignored.

### Negative

- Dirty scheduler dispatch adds overhead to very small hot-cache operations.
- Synchronous WAL writes are substantially slower and should be used only at
  meaningful durability boundaries.
- `DbResource` and child-resource lifetime management become more complex.
- Bulk iterator calls allocate lists of binaries and therefore require strict
  native bounds.
- Unknown-option rejection may expose configurations that appeared to work only
  because options were silently ignored.
- New native APIs require new precompiled artifacts for every supported target.

### Neutral

- Existing database files remain compatible.
- Existing batch atomicity is unchanged.
- Applications that accept current durability defaults need not opt into
  synchronous writes.
- Applications already using process ownership can continue doing so; explicit
  close makes the lifecycle guarantee visible and testable.

## Rejected Alternatives

### Treat atomic `write_batch/2` as a durable commit

Rejected because atomic visibility and machine-crash durability are different
properties. Naming or documentation cannot substitute for RocksDB
`WriteOptions.sync`.

### Make every write synchronous by default

Rejected because it would materially change performance and current behavior.
Durability must be explicit at meaningful commit boundaries.

### Use `set_use_fsync: true` as the durability API

Rejected because that database option selects the filesystem synchronization
mechanism; it does not request synchronous completion for each write. Per-write
`sync` remains necessary.

### Build pagination by repeatedly reopening range iterators

Rejected because separate iterators can observe different database states and
must repeatedly seek. Advancing one iterator resource preserves its view and is
more efficient.

### Return an unbounded list for an entire range

Rejected because native allocation and BEAM heap transfer would be controlled
by database contents rather than the caller.

### Leave point reads on normal schedulers because they are usually cached

Rejected because cache state is not a scheduling guarantee. Embedded storage
calls can block, and unrelated BEAM processes should not depend on RocksDB cache
warmth.

### Implement close by immediately removing `DB` regardless of children

Rejected because iterators and snapshots hold native references tied to the
database lifetime. Forced invalidation risks memory unsafety.

### Rely exclusively on garbage collection for closure

Rejected because path rotation, deterministic test cleanup, and immediate
reopen require an explicit completion boundary.

### Introduce `:end_of_table` as a second accepted terminal atom

Rejected because the implementation and tests already establish
`:end_of_iterator`. Correcting documentation avoids permanent dual semantics.

### Continue ignoring unknown options

Rejected because silent configuration failure is dangerous for durability and
operational tuning.

## Follow-Up Work

After this ADR is implemented, consider separately:

- Convenience write-option arities for point and column-family operations.
- Telemetry for operation duration, dirty scheduler queue time, bytes returned,
  and synchronous write frequency.
- A supervised OTP database owner included with ExRocket rather than requiring
  every application to implement one.
- Read-only close semantics and explicit backup/checkpoint resource ownership.
- Automated generation of option documentation from the native option schema.

Those items are useful but are not prerequisites for the consistency guarantees
defined here.
