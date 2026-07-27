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

Use a column family to keep related data separate:

```elixir
:ok = ExRocket.create_cf(db, "sessions")
:ok = ExRocket.put_cf(db, "sessions", "token", "active")
{:ok, "active"} = ExRocket.get_cf(db, "sessions", "token")
```

See the [full cheatsheet](https://github.com/mindreframer/ex_rocket/blob/main/CHEATSHEET.md) for iterators, merge operators, snapshots, checkpoints, backups, options, and error-handling patterns.

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
- Atomic batch writes
- Flexible database options
- Range and prefix iterators
- Range deletion
- Multi-get
- Snapshots
- Checkpoints
- Backup API
- Counter, Erlang term, and bitset merge operators

## Performance

ExRocket's hot-key microbenchmark on an Apple M3 Ultra measured approximately 2.46 million reads/second and 470,000 writes/second. Real workloads will vary with key/value size, cache hit rate, durability settings, compaction, and storage hardware.

## Source build requirements

- Erlang 24 or newer
- Rust 1.91 or newer; the version is pinned in `rust-toolchain.toml`
- Clang 15 or newer

## Validation

Run `scripts/roadmap001_check.sh` to format, source-build, and test ExRocket.

## Release

1. Bump the version in `mix.exs` and `native/rocker/Cargo.toml`.
2. Tag the release, for example: `git tag v0.4.0`.
3. Push the tag: `git push origin v0.4.0`.
4. Wait for all precompiled NIFs to be uploaded.
5. Run `mix rustler_precompiled.download ExRocket --all`.
6. Verify the checksum file and NIF artifact set.
7. Build and publish with `mix hex.publish`.

## Status

Passed all functional and performance tests.

## License

ExRocket is licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).
