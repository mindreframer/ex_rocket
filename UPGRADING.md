# Upgrading To ExRocket 0.5.0

ExRocket 0.5.0 preserves RocksDB files, keys, values, column families, merge
operators, existing batch tuples, and the default `write_batch/2` behavior. No
on-disk migration is required.

## Audit Option Maps Before Upgrade

Unknown database, read, write, and iterator option keys now fail visibly:

```elixir
{:error, {:unknown_option, :max_open_files}} =
  ExRocket.open(path, %{max_open_files: 1_000})
```

Use the exact names in [`OPTIONS.md`](OPTIONS.md), for example:

```elixir
%{
  set_max_open_files: 1_000,
  set_write_buffer_size: 64 * 1024 * 1024,
  set_target_file_size_base: 64 * 1024 * 1024,
  set_max_bytes_for_level_base: 256 * 1024 * 1024
}
```

Search application configuration, runtime environment conversion, and
column-family descriptors for keys that 0.4.x silently ignored. Malformed values
return `{:error, {:invalid_option, key}}`; new write and iterator APIs retain
their dedicated `:invalid_write_options` and `:invalid_iterator_options` errors.

## Choose Durability Explicitly

`write_batch/2` remains atomic, WAL-enabled, and non-synchronous. Callers that
interpret acknowledgement as a machine-crash durability boundary should use:

```elixir
ExRocket.write_batch(db, operations, %{sync: true})
```

Do not use `disable_wal: true` for durable state. `set_use_fsync` chooses the
filesystem synchronization mechanism but does not request a synchronous write.

## Release Iterators And Snapshots Before Close

`close/1` is deterministic and idempotent, but returns
`{:error, :resource_busy}` while native children retain the database. Stop their
owner processes or release those terms before retrying. Operations through a
successfully closed resource return `{:error, :closed}`.

## Iterator Consumers

The sole `next/1` terminal remains `:end_of_iterator`. Bulk consumers can use
`iterator_take/2`; `:more` means a bound was reached and
`:end_of_iterator` means exhaustion was observed.

## Rollback

Because the on-disk format is unchanged, an orderly rollback to 0.4.1 can reopen
the same database after all 0.5.0 resources are closed. Remove calls to new
arities before rolling application code back. Configuration keys corrected for
0.5.0 remain the canonical keys accepted by the 0.4.1 native decoder.
