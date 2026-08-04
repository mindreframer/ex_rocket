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
one process, forward iteration, and no explicit snapshot.

## EPIC007 Release Comparison

The following final local comparison used the same Apple M3 Ultra/macOS
26.5.1 environment recorded above. Point operations ran in clean source-built
0.4.1 and 0.5.0 worktrees with the same script, one process, one hot read key,
100,000 reads, and 100,000 unique-key default non-synchronous writes.

| Workload | 0.4.1 | 0.5.0 | Context |
| --- | ---: | ---: | --- |
| Hot point reads/s | 2,707,605.7 | 344,073.0 | Normal NIF in 0.4.1; `DirtyIo` in 0.5.0. |
| Point writes/s | 476,045.4 | 38,145.7 | WAL enabled/non-sync; `DirtyIo` in 0.5.0. |
| Non-sync batch operations/s | not measured | 253,842.5 | 200 batches of 100 128-byte values. |
| Sync boundaries/s | unavailable | 231.8 | 100 one-row `%{sync: true}` batches. |
| `next/1`, 50,000 rows | not rerun | 89,590 us | 12-byte keys, 128-byte values, warm forward scan. |
| `iterator_take/2`, 50,000 rows | unavailable | 17,496 us | 1,000-row pages, same scan. |
| Snapshot `iterator_take/2`, 50,000 rows | unavailable | 17,764 us | 1,000-row pages from one stable snapshot. |
| Close p50/p95/max | unavailable | 252/314/422 us | 50 fresh databases. |

Dirty scheduler isolation intentionally trades hot-call microbenchmark
throughput for bounded impact on normal BEAM schedulers. Bulk iteration
amortizes that dispatch cost. The 0.5.0 1,000-row page contained 139,620 payload
bytes, increased process memory by approximately 175,344 bytes during the
measurement, and remained below both native bounds.

The final large scheduler run used 50,000 rows, 2,048-byte values, eight
concurrent readers, default options, and a warm second pass:

```text
first_pass_us=238364 hot_pass_us=176160
concurrent_read_ops_per_second=179846.8
heartbeat_samples=361
heartbeat_p95_us=6975 heartbeat_max_us=10048
```

Commands:

```sh
POINT_BENCH_OPERATIONS=100000 mix run benchmark/point.exs
mix run benchmark/release.exs
ITERATOR_BENCH_COUNT=50000 ITERATOR_BENCH_PAGE_SIZE=1000 \
  mix run benchmark/iterator.exs
SCHEDULER_BENCH_ROWS=50000 SCHEDULER_BENCH_VALUE_BYTES=2048 \
SCHEDULER_BENCH_WORKERS=8 mix run benchmark/scheduler.exs
```

All commands used `RUSTUP_TOOLCHAIN=1.91.0`, `FORCE_BUILD=yes`, and
`MIX_ENV=test`. Results are comparative evidence, not portable service-level
objectives.
