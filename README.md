# ExRocket

[![Tests](https://github.com/mindreframer/ex_rocket/actions/workflows/elixir.yml/badge.svg?branch=main)](https://github.com/mindreframer/ex_rocket/actions/workflows/elixir.yml)
[![Build precompiled NIFs](https://github.com/mindreframer/ex_rocket/actions/workflows/release_with_caching.yml/badge.svg?branch=main)](https://github.com/mindreframer/ex_rocket/actions/workflows/release_with_caching.yml)

## About

ExRocket is an Elixir NIF backed by [RocksDB](https://github.com/facebook/rocksdb) through Rust. It provides a safe, fast API while keeping keys and values as binaries, so applications can choose their own storage format.

ExRocket is a continuation of [Rocker](https://github.com/Vonmo/rocker), a RocksDB NIF for Erlang.

> **Looking for the complete API reference?** See the [ExRocket Cheatsheet](https://github.com/mindreframer/ex_rocket/blob/main/CHEATSHEET.md) for examples covering key/value operations, column families, batches, iterators, snapshots, backups, and merge operators.

## Installation

Add `ex_rocket` to the dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_rocket, "~> 0.4"}
  ]
end
```

## Quick start

Open a database, write binary keys and values, and read them back:

```elixir
db_path = Path.join(System.tmp_dir!(), "my_ex_rocket_db")

{:ok, db} = ExRocket.open(db_path, %{create_if_missing: true})

:ok = ExRocket.put(db, "greeting", "hello")
{:ok, "hello"} = ExRocket.get(db, "greeting")
:undefined = ExRocket.get(db, "missing")

:ok = ExRocket.delete(db, "greeting")
```

Write several changes atomically:

```elixir
{:ok, 3} =
  ExRocket.write_batch(db, [
    {:put, "user:1", "alice"},
    {:put, "user:2", "bob"},
    {:delete, "obsolete"}
  ])

{:ok, [{:ok, "alice"}, {:ok, "bob"}, :undefined]} =
  ExRocket.multi_get(db, ["user:1", "user:2", "missing"])
```

Atomic visibility is not the same as machine-crash durability. The default
batch path keeps the WAL enabled but does not request a synchronous filesystem
flush. ExRocket 0.5.0 adds `write_batch/3` for explicit durability boundaries:

```elixir
{:ok, 1} =
  ExRocket.write_batch(
    db,
    [{:put, "materialization/checkpoint", "clean:42"}],
    %{sync: true}
  )
```

The write-option defaults are `%{sync: false, disable_wal: false}`. Do not
combine `sync: true` with `disable_wal: true`; a synchronous WAL guarantee
cannot be provided while the WAL is disabled. WAL-disabled writes are intended
only for rebuildable bulk-load data.

Applications that deliberately group non-synchronous writes can establish a
separate WAL boundary with `ExRocket.flush_wal(db, true)`. A synchronous clean
checkpoint written with `write_batch/3` is usually easier to reason about.

Use a column family to keep related data separate:

```elixir
:ok = ExRocket.create_cf(db, "sessions")
:ok = ExRocket.put_cf(db, "sessions", "token", "active")
{:ok, "active"} = ExRocket.get_cf(db, "sessions", "token")
```

Page through one stable iterator view with bounded native transfers:

```elixir
{:ok, iterator} = ExRocket.iterator(db, {:start})

{:ok, rows, status} =
  ExRocket.iterator_take(iterator, %{
    max_entries: 1_000,
    max_bytes: 4 * 1024 * 1024
  })
```

`max_entries` is required and capped at 100,000. `max_bytes` counts key/value
payload, is capped at 64 MiB, and excludes Erlang term overhead. If the first
row alone exceeds the byte limit, it is returned to guarantee progress. A
bound-first page returns `:more`; only observed exhaustion returns
`:end_of_iterator`.

Release the database path deterministically when ownership ends:

```elixir
:ok = ExRocket.close(db)
:ok = ExRocket.close(db) # idempotent
{:error, :closed} = ExRocket.get(db, "key")
```

A live iterator or snapshot keeps its native owner safe, so close returns
`{:error, :resource_busy}` until that child resource is released. Successful
close drops RocksDB and releases its filesystem lock before returning; normal
resource garbage collection remains a fallback.

See the
[full cheatsheet](https://github.com/mindreframer/ex_rocket/blob/main/CHEATSHEET.md)
for iterators, merge operators, snapshots, checkpoints, backups, and
error-handling patterns. Configuration keys and types are defined in the
[canonical option reference](OPTIONS.md); existing applications should follow
the [0.5.0 upgrade guide](UPGRADING.md).

## Technology

| Elixir module | Native crate | Rust package | Bundled RocksDB |
| --- | --- | --- | --- |
| `ExRocket` | `native/rocker` | `rust-rocksdb 0.51` | 11.1.2 |

## Supported OS

Precompiled NIFs are published for:

- Apple Silicon and Intel macOS
- ARM64 and x86-64 Linux with glibc
- ARM64 and x86-64 Linux with musl, including Alpine Linux
- x86-64 Windows

Other targets can build from source with `FORCE_BUILD=1` and the build requirements below.

## Features

- Key/value operations
- Column families
- Atomic batch writes with explicit sync/WAL options
- Exact, validated database options
- Range, prefix, and bounded bulk iterators
- Range deletion
- Multi-get
- Snapshots
- Deterministic safe database close
- Checkpoints
- Backup API
- Counter, Erlang term, and bitset merge operators

## Performance

Storage-backed NIFs run on Rustler dirty I/O schedulers so cache misses, WAL
flushes, iterator walks, and native lock waits do not block normal BEAM
schedulers. Dirty dispatch adds overhead to very small hot-cache calls; use
`iterator_take/2` to amortize NIF transitions during scans.

ExRocket's historical normal-scheduler hot-key microbenchmark measured
approximately 2.46 million reads/second and 470,000 writes/second on an Apple M3
Ultra. ADR002 benchmark reports include both storage throughput and independent
BEAM heartbeat latency. Real workloads vary with key/value size, cache state,
durability settings, compaction, concurrency, and storage hardware.

## Source build requirements

- Erlang 24 or newer
- Rust 1.91 or newer; the version is pinned in `rust-toolchain.toml`
- Clang 15 or newer

## Validation

Run `scripts/qa_check.sh` for the staged Elixir, Rust, NIF smoke, and package
quality gate. Successful dependency setup stays quiet; failures retain their
complete diagnostic output.

CI uses source-aware Mix/Cargo caches with lockfile restore keys, per-target
release caches, and no-Rust consumer jobs that compile the unpacked Hex package
and load each published native artifact through the public API.

## Release

1. Bump the version in `mix.exs` and `native/rocker/Cargo.toml`; verify parity
   with `scripts/project_version.sh`.
2. Run `scripts/qa_check.sh` and push the green version commit.
3. Dispatch `Build precompiled NIFs` with `publish: false`; verify all seven
   target builds and functional smoke tests.
4. Dispatch the same workflow with `publish: true`. It validates the exact
   artifact set and digests in a draft before atomically publishing the tag and
   GitHub release.
5. Run `mix clean && mix compile`, followed by
   `mix rustler_precompiled.download ExRocket --all` locally.
6. Commit the generated checksum manifest and require all source and
   no-Rust precompiled-consumer CI jobs to pass.
7. Inspect the unpacked package before publishing Hex.

## Status

Passed all functional and performance tests.

## License

ExRocket is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).
