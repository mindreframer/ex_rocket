# ROADMAP002 NIF Scheduler Audit

**Policy:** Every NIF that can touch RocksDB storage, wait on a native resource
lock, mutate metadata, or advance an iterator runs on `DirtyIo`. `DirtyCpu` is
not used because these operations primarily wait on I/O or locks. The inventory
is checked mechanically by `test/contract_baseline_test.exs`.

## Classification

| Export | Class | Rationale |
| --- | --- | --- |
| `lxcode` | Normal | Encodes two constant atoms; no resource, lock, allocation proportional to data, or storage access. |
| `latest_sequence_number` | DirtyIo | Takes the database resource lock, which can wait behind metadata mutation or close. |
| `get_db_path` | DirtyIo | Takes the database resource lock, which can wait behind metadata mutation or close. |
| `open`, `open_for_read_only`, `open_cf`, `open_cf_for_read_only` | DirtyIo | Opens files, acquires filesystem locks, and may recover RocksDB state. |
| `destroy`, `repair` | DirtyIo | Performs blocking filesystem/database maintenance. |
| `close` | DirtyIo | Waits for the exclusive database lock and drops RocksDB, which can wait for background work and path-lock release. |
| `put`, `get`, `delete`, `merge` | DirtyIo | Can access storage, WAL, memtables, caches, and native locks. |
| `put_cf`, `get_cf`, `delete_cf`, `merge_cf` | DirtyIo | Resolves a CF under the DB lock and can access storage/WAL. |
| `write_batch`, `flush_wal` | DirtyIo | Writes WAL/storage or explicitly waits for a WAL flush/sync. |
| `delete_range`, `delete_range_cf` | DirtyIo | Applies storage-backed range tombstones. |
| `multi_get`, `multi_get_cf` | DirtyIo | Can perform multiple cache misses and storage reads. |
| `key_may_exist`, `key_may_exist_cf` | DirtyIo | Consults RocksDB state and may wait on DB/native locks. |
| `create_cf`, `drop_cf`, `list_cf` | DirtyIo | Reads or mutates column-family/storage metadata. |
| `iterator`, `iterator_range`, `prefix_iterator` | DirtyIo | Creates storage-backed iterators and may seek/read metadata. |
| `iterator_cf`, `prefix_iterator_cf` | DirtyIo | Resolves CF state and creates/seeks storage-backed iterators. |
| `next`, `iterator_take` | DirtyIo | Walks RocksDB iterators and copies database-controlled payloads. |
| `snapshot` | DirtyIo | Takes the DB lock and creates native snapshot state. |
| `snapshot_get`, `snapshot_multi_get` | DirtyIo | Performs snapshot-backed storage reads under native locks. |
| `snapshot_get_cf`, `snapshot_multi_get_cf` | DirtyIo | Takes DB/snapshot locks and performs CF storage reads. |
| `snapshot_iterator`, `snapshot_iterator_cf` | DirtyIo | Takes snapshot/DB locks and creates storage-backed iterators. |
| `create_checkpoint` | DirtyIo | Creates filesystem links/files and waits on RocksDB state. |
| `create_backup`, `get_backup_info`, `purge_old_backups`, `restore_from_backup` | DirtyIo | Opens backup storage and performs filesystem/database operations. |

## Maintenance Rule

Every future `#[rustler::nif]` export must be added to the mechanical inventory
and this audit before CI can pass.

## Benchmark Dimensions

Scheduler evidence must report both storage throughput and unrelated BEAM
responsiveness:

1. Hot point-operation throughput.
2. Cold or sufficiently large read latency.
3. `next/1` and `iterator_take/2` scan throughput.
4. Dirty-scheduler saturation and independent heartbeat latency.

Results are environment-sensitive; reports must include hardware, OS, data
size, operation options, warm/cold state, and concurrency.
