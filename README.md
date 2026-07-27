# ExRocket

[![Tests](https://github.com/mindreframer/ex_rocket/actions/workflows/elixir.yml/badge.svg?branch=main)](https://github.com/mindreframer/ex_rocket/actions/workflows/elixir.yml)
[![Build precompiled NIFs](https://github.com/mindreframer/ex_rocket/actions/workflows/release_with_caching.yml/badge.svg?branch=main)](https://github.com/mindreframer/ex_rocket/actions/workflows/release_with_caching.yml)

## About

ExRocket is NIF for Elixir which uses Rust binding for [RocksDB](https://github.com/facebook/rocksdb). Its key features are safety, performance and a minimal codebase. The keys and data are kept binary and this doesn’t impose any restrictions on storage format. So far the project is suitable for being used in third-party solutions.
ExRocket is a logical continuation of [Rocker](https://github.com/Vonmo/rocker) - NIF for Erlang

## Installation
The package can be installed by adding `ex_rocket` to your list of dependencies in `mix.exs`:
```
def deps do
  [{:ex_rocket, "~> 0.4"}]
end
```

## Backend and version

ExRocket uses the actively maintained `rust-rocksdb` package:

| Public module | Native crate | Rust package | Bundled RocksDB |
| --- | --- | --- | --- |
| `ExRocket` | `native/rocker` | `rust-rocksdb 0.51` | 11.1.2 |

`ExRocket` is the only public backend module. The former `rocksdb 0.24` /
RocksDB 10.4.2 implementation and the temporary parallel migration module were
removed after validation.

## Supported OS
* Linux
* Windows
* macOS

Precompiled NIFs are published for Apple Silicon and Intel macOS, ARM64 and
x86-64 Linux with either glibc or musl (including Alpine Linux), and x86-64
Windows. Other targets can build from source with `FORCE_BUILD=1` and the build
requirements below.

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

The maintained backend's hot-key microbenchmark on an Apple M3 Ultra measured
approximately 2.46 million reads/second and 470,000 writes/second. Real workloads
will vary with key/value size, cache hit rate, durability settings, compaction,
and storage hardware.

## Build Information
ExRocket requires
* Erlang >= 24.
* Rust >= 1.91 (pinned by `rust-toolchain.toml`).
* Clang >= 15.


## Release
- bump the version in `mix.exs`
- bump the version in `native/rocker/Cargo.toml`
- tag a release `git tag v0.4.0`
- push the tag: `git push origin v0.4.0`
- wait for the compiled libs to be uploaded (takes around 15 minutes if all goes well)
- run `mix rustler_precompiled.download ExRocket --all`
- verify the generated checksum file and NIF artifact set
- now you can publish: `mix hex.publish`

## Validation

Run `scripts/roadmap001_check.sh` to format, source-build, and test the native
backend. The original ExRocket tests run unchanged against the maintained NIF.

## On-disk compatibility

Before removing the old native crate, a lightweight bidirectional migration
check was executed against RocksDB 10.4.2 and RocksDB 11.1.2. It wrote with each
backend in a separate BEAM process, closed the database, and read it with the
other backend. It covered binary and Unicode values, empty and larger values,
Erlang external terms, write batches, deletions, column families, and CF
batches. Both directions passed:

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
