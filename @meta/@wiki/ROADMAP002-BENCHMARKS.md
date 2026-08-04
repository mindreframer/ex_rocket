# ROADMAP002 Benchmark Record

This file records reproducible development evidence. EPIC007 adds the final
0.4.1-versus-0.5.0 release comparison and artifact-platform results.

## EPIC004 Scheduler Isolation Sample

**Date:** 2026-08-04

**Environment**

- Apple M3 Ultra, 256 GiB RAM
- macOS 26.5.1 (Darwin 25.5.0, ARM64)
- Erlang/OTP 29, Elixir 1.20.1
- Rust 1.91.0
- `rust-rocksdb 0.51.0`, bundled RocksDB 11.1.2
- ExRocket source-built release NIF
- Default database/write options; WAL enabled; non-synchronous writes

**Scheduler workload**

```sh
RUSTUP_TOOLCHAIN=1.91.0 FORCE_BUILD=yes MIX_ENV=test \
SCHEDULER_BENCH_ROWS=20000 \
SCHEDULER_BENCH_VALUE_BYTES=2048 \
SCHEDULER_BENCH_WORKERS=8 \
mix run --no-compile benchmark/scheduler.exs
```

The 40 MiB logical data set was read once, read again hot, and then read by
eight concurrent workers while an independent normal-scheduler heartbeat ran.

```text
rows=20000 value_bytes=2048 workers=8
first_pass_us=49753 hot_pass_us=51333
concurrent_read_ops_per_second=185342.9
heartbeat_samples=142
heartbeat_p95_us=6686 heartbeat_max_us=8318
```

This is scheduler-responsiveness evidence, not a portable performance target.
The script accepts larger data/value settings for storage colder than this
development sample.

**Iterator workload**

```sh
RUSTUP_TOOLCHAIN=1.91.0 FORCE_BUILD=yes MIX_ENV=test \
ITERATOR_BENCH_COUNT=20000 ITERATOR_BENCH_PAGE_SIZE=1000 \
mix run --no-compile benchmark/iterator.exs
```

```text
rows=20000 page_size=1000
next/1: 20000 rows in 45710 us
iterator_take/2: 20000 rows in 7066 us
```

The iterator comparison uses 12-byte keys, 128-byte values, a warm database,
one process, forward iteration, and no explicit snapshot. The release report
will add cold/large scans, multiple page sizes, and snapshot scans.
