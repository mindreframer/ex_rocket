# ROADMAP002 Baseline Inventory

**Baseline:** ExRocket 0.4.1 before ADR002 native behavior changes.

This inventory is paired with `test/contract_baseline_test.exs`, which checks the
public function and native NIF/scheduler lists mechanically. ADR002 is
responsible for deliberate changes to this baseline.

## Native Resources

| Resource | Native state | Dependency |
| --- | --- | --- |
| `DbResource` | `RwLock<DB>` | Owns RocksDB and its path lock; GC drops it. |
| `SnapshotResource` | `Mutex<Snapshot<'static>>` | Retains one `ResourceArc<DbResource>`. |
| `IteratorResource` | `Mutex<DBIterator<'static>>` | Retains a database owner and optionally a snapshot owner. |

Iterator and snapshot lifetimes are extended only while their resource owners
remain retained. There is no explicit closed state or dependent lease count.

## Native NIF Inventory

`Normal` is the pre-ADR002 normal-scheduler baseline, not the desired final
classification.

| NIF | Scheduler | Native dependency | Current success shape |
| --- | --- | --- | --- |
| `lxcode` | Normal | none | `{:ok, :vsn1}` |
| `latest_sequence_number` | Normal | DB | `{:ok, non_neg_integer}` |
| `open` | DirtyIo | path | `{:ok, db}` |
| `open_for_read_only` | DirtyIo | path | `{:ok, db}` |
| `destroy` | DirtyIo | path | `:ok` |
| `repair` | DirtyIo | path | `:ok` |
| `get_db_path` | Normal | DB | `{:ok, String.t()}` |
| `put` | Normal | DB | `:ok` |
| `get` | Normal | DB | `{:ok, binary} | :undefined` |
| `delete` | Normal | DB | `:ok` |
| `merge` | Normal | DB | `:ok` |
| `merge_cf` | Normal | DB/CF | `:ok` |
| `write_batch` | DirtyIo | DB/CF | `{:ok, non_neg_integer}` |
| `delete_range` | DirtyIo | DB | `:ok` |
| `multi_get` | Normal | DB | `{:ok, [read_result]}` |
| `key_may_exist` | Normal | DB | `{:ok, boolean}` |
| `create_cf` | DirtyIo | DB | `:ok` |
| `open_cf` | DirtyIo | path/CF | `{:ok, db}` |
| `open_cf_for_read_only` | DirtyIo | path/CF | `{:ok, db}` |
| `list_cf` | DirtyIo | path | `{:ok, [String.t()]}` |
| `drop_cf` | Normal | DB/CF | `:ok` |
| `put_cf` | Normal | DB/CF | `:ok` |
| `get_cf` | Normal | DB/CF | `{:ok, binary} | :undefined` |
| `delete_cf` | Normal | DB/CF | `:ok` |
| `delete_range_cf` | DirtyIo | DB/CF | `:ok` |
| `multi_get_cf` | Normal | DB/CF | `{:ok, [read_result]}` |
| `key_may_exist_cf` | Normal | DB/CF | `{:ok, boolean}` |
| `iterator` | Normal | DB | `{:ok, iterator}` |
| `iterator_range` | Normal | DB | `{:ok, iterator}` |
| `prefix_iterator` | Normal | DB | `{:ok, iterator}` |
| `iterator_cf` | Normal | DB/CF | `{:ok, iterator}` |
| `prefix_iterator_cf` | Normal | DB/CF | `{:ok, iterator}` |
| `snapshot` | Normal | DB | `{:ok, snapshot}` |
| `snapshot_get` | Normal | snapshot | `{:ok, binary} | :undefined` |
| `snapshot_get_cf` | Normal | snapshot/DB/CF | `{:ok, binary} | :undefined` |
| `snapshot_multi_get` | Normal | snapshot | `{:ok, [read_result]}` |
| `snapshot_multi_get_cf` | Normal | snapshot/DB/CF | `{:ok, [read_result]}` |
| `snapshot_iterator` | Normal | snapshot | `{:ok, iterator}` |
| `snapshot_iterator_cf` | Normal | snapshot/DB/CF | `{:ok, iterator}` |
| `create_checkpoint` | DirtyIo | DB/path | `:ok` |
| `create_backup` | DirtyIo | DB/path | `{:ok, [backup_info]}` |
| `get_backup_info` | DirtyIo | path | `{:ok, [backup_info]}` |
| `purge_old_backups` | DirtyIo | path | `{:ok, [backup_info]}` |
| `restore_from_backup` | DirtyIo | path | `:ok` |
| `next` | Normal | iterator | `{:ok, binary, binary} | :end_of_iterator` |

Native RocksDB failures are currently `{:error, String.t()}`. Unknown column
families use `{:error, :unknown_cf}`. Decode failures may raise `ArgumentError`.

## Option Decoders

| Decoder | Used by | Baseline behavior |
| --- | --- | --- |
| `RockerOptions` | database/CF open, create/list/destroy/repair | Canonical keys are decoded; unknown keys are silently ignored. |
| `RockerReadOptions` | `iterator_range/5` | `iterate_upper_bound` and `iterate_lower_bound`; unknown keys are silently ignored. |

Write and iterator-take option decoders do not exist at baseline. Public examples
must use canonical names such as `set_max_open_files` and
`set_write_buffer_size`.

## Roadmap Evolution

The mechanically checked NIF list is updated as epics add exports. EPIC002 adds
`flush_wal` on `DirtyIo` and changes the native `write_batch` export from arity
2 to arity 3 while the Elixir `write_batch/2` compatibility wrapper remains.
EPIC003 adds bounded `iterator_take` and moves `next` to `DirtyIo`; EPIC004
completes the scheduler audit for all remaining exports.

## Protected Compatibility Semantics

- `write_batch/2` uses WAL-enabled, non-synchronous RocksDB defaults and returns
  the number of batch operations.
- Existing batch tuples, including historically accepted extra delete-tuple
  fields, retain their behavior.
- `next/1` terminates only with `:end_of_iterator`.
- Iterators and snapshots retain the database resource, so its path lock remains
  held until all owners are released.
- GC-based database closure remains available.
- Existing on-disk databases and binary key/value bytes require no migration.
