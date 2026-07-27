# ExRocket

[![Tests](https://github.com/mindreframer/ex_rocket/actions/workflows/elixir.yml/badge.svg?branch=main)](https://github.com/mindreframer/ex_rocket/actions/workflows/elixir.yml)
[![Build precompiled NIFs](https://github.com/mindreframer/ex_rocket/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/mindreframer/ex_rocket/actions/workflows/release.yml)

## About

ExRocket is NIF for Elixir which uses Rust binding for [RocksDB](https://github.com/facebook/rocksdb). Its key features are safety, performance and a minimal codebase. The keys and data are kept binary and this doesn’t impose any restrictions on storage format. So far the project is suitable for being used in third-party solutions.
ExRocket is a logical continuation of [Rocker](https://github.com/Vonmo/rocker) - NIF for Erlang

## Installation
The package can be installed by adding `ex_rocket` to your list of dependencies in `mix.exs`:
```
def deps do
  [{:ex_rocket, "~> 0.3"}]
end
```

## Backends and versions

ExRocket ships two independent modules so the stable and maintained bindings can
be tested and benchmarked side by side:

| Elixir module | Native crate | Rust package | Bundled RocksDB |
| --- | --- | --- | --- |
| `ExRocket` | `native/rocker` | `rocksdb 0.24` | 10.4.2 |
| `ExRocket.RustRocksDB` | `native/rocker_maintained` | `rust-rocksdb 0.51` | 11.1.2 |

Both modules expose the same function names and arities. They use distinct NIF
resources and native libraries; no transparent runtime switch or shared database
handle is involved. New integrations can call `ExRocket.RustRocksDB` directly,
while existing `ExRocket` callers remain unchanged.

Run the comparative benchmark with:

```sh
RUSTUP_TOOLCHAIN=1.91.0 FORCE_BUILD=yes MIX_ENV=dev mix run benchmark/compare.exs
```

Use `BENCH_TIME` and `BENCH_WARMUP` to shorten or extend a run.

## Supported OS
* Linux
* Windows
* MacOS

## Features
* kv operations
* column families support
* batch write
* support of flexible storage setup
* range iterator
* delete range
* multi get
* snapshots
* checkpoints (Online backups)
* backup api
* merge operators (counter, erlang term, bitset)

## Main requirements for a driver
* Reliability
* Performance
* Minimal codebase
* Safety
* Functionality

## Performance
In a set of tests you can find a performance test. It demonstrates about 135k write RPS and 2.1M read RPS on my machine. In real conditions we might expect something about 50k write RPS and 400k read RPS with average amount of data being about 1 kB per key and the total number of keys exceeding 1 billion.

## Build Information
ExRocket requires
* Erlang >= 24.
* Rust >= 1.91 for the maintained backend (pinned by `rust-toolchain.toml`).
* Clang >= 15.


## Release
- bump the version in `mix.exs`
- bump the version in both native `Cargo.toml` files
- tag a release `git tag v0.3.0`
- push the tag: `git push mindrefamer v0.3.0`
- wait for the compiled libs to be uploaded (takes around 15 minutes if all goes well)
- run `mix rustler_precompiled.download ExRocket --all`
- run `mix rustler_precompiled.download ExRocket.RustRocksDB --all`
- verify both checksum files and both distinctly named NIF artifact sets
- now you can publish: `mix hex.publish`

## Parallel backend validation and rollback

Run `scripts/roadmap001_check.sh` to format, source-build, and test both backends.
Set `RUN_BENCHMARK_SMOKE=1` to include a short comparative benchmark. Because the
implementations are separate modules and crates, rollback is simply returning
callers to `ExRocket`; removing the maintained experiment does not require
rewriting the legacy backend.

## On-disk compatibility

A lightweight bidirectional check verifies the database formats used by the
legacy RocksDB 10.4.2 backend and maintained RocksDB 11.1.2 backend:

```sh
scripts/check_rocksdb_compatibility.sh
```

The check writes with each backend in a separate BEAM process, closes the
database, and reads it with the other backend. It covers binary and Unicode
values, empty and larger values, Erlang external terms, write batches,
deletions, column families, and CF batches. Both directions currently pass:

```text
RocksDB 10.4.2 write -> RocksDB 11.1.2 read: PASS
RocksDB 11.1.2 write -> RocksDB 10.4.2 read: PASS
```

This is a practical compatibility signal, not a guarantee for every RocksDB
option, SST format, merge operator, or future version. Production migrations
should still retain backups and validate representative data before rollback.

## Status
Passed all the functional and performance tests.

## License
ExRocket's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)
