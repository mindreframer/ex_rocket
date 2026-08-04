# ExRocket Option Reference

This is the canonical public option inventory for ExRocket 0.5.0. The CI option
inventory test compares every key below with the native decoders. Unknown keys
return `{:error, {:unknown_option, key}}`; malformed values return
`{:error, {:invalid_option, key}}` before a database is opened or mutated.

Database option keys intentionally mirror the maintained `rust-rocksdb` API.
There are no shortened aliases such as `max_open_files` or
`write_buffer_size`. `set_use_fsync` chooses RocksDB's synchronization mechanism;
it does not make each write synchronous. Use `write_batch/3` with `%{sync:
true}` for a synchronous write boundary.

## Database And Column-Family Options

All keys are optional. `nil` below means the option is not applied and RocksDB's
native default remains in effect. ExRocket's only explicit database default is
`create_if_missing: true`.

String constraints:

- Compression: `None`, `Snappy`, `Zlib`, `Bz2`, `Lz4`, `Lz4hc`, or `Zstd`
  (case-insensitive).
- `set_log_level`: `Debug`, `Info`, `Warn`, `Error`, `Fatal`, or `Header`.
- `set_compaction_style`: `Level`, `Universal`, or `Fifo`.
- `set_wal_recovery_mode`: `TolerateCorruptedTailRecords`,
  `AbsoluteConsistency`, `PointInTime`, or `SkipAnyCorruptedRecord`.
- `merge_operator`: `counter_merge_operator`, `erlang_merge_operator`, or
  `bitset_merge_operator`.
- `set_max_bytes_for_level_multiplier_additional`: comma-separated `i32`
  values.
- `set_ratelimiter`: exactly three comma-separated integers representing bytes
  per second, refill period in microseconds, and fairness.

| Key | Elixir value type | ExRocket default | Native mapping |
| --- | --- | --- | --- |
| `create_if_missing` | `boolean()` | `true` | `Options::create_if_missing` |
| `create_missing_column_families` | `boolean()` | `nil` | `Options::create_missing_column_families` |
| `set_error_if_exists` | `boolean()` | `nil` | `Options::set_error_if_exists` |
| `set_paranoid_checks` | `boolean()` | `nil` | `Options::set_paranoid_checks` |
| `increase_parallelism` | `integer()` | `nil` | `Options::increase_parallelism` |
| `optimize_level_style_compaction` | `non_neg_integer()` | `nil` | `Options::optimize_level_style_compaction` |
| `optimize_universal_style_compaction` | `non_neg_integer()` | `nil` | `Options::optimize_universal_style_compaction` |
| `set_compression_type` | `String.t()` | `nil` | `Options::set_compression_type` |
| `set_bottommost_compression_type` | `String.t()` | `nil` | `Options::set_bottommost_compression_type` |
| `set_zstd_max_train_bytes` | `integer()` | `nil` | `Options::set_zstd_max_train_bytes` |
| `set_compaction_readahead_size` | `non_neg_integer()` | `nil` | `Options::set_compaction_readahead_size` |
| `set_level_compaction_dynamic_level_bytes` | `boolean()` | `nil` | `Options::set_level_compaction_dynamic_level_bytes` |
| `set_optimize_filters_for_hits` | `boolean()` | `nil` | `Options::set_optimize_filters_for_hits` |
| `set_delete_obsolete_files_period_micros` | `non_neg_integer()` | `nil` | `Options::set_delete_obsolete_files_period_micros` |
| `set_max_open_files` | `integer()` | `nil` | `Options::set_max_open_files` |
| `set_max_file_opening_threads` | `integer()` | `nil` | `Options::set_max_file_opening_threads` |
| `set_use_fsync` | `boolean()` | `nil` | `Options::set_use_fsync` |
| `set_db_log_dir` | `String.t()` | `nil` | `Options::set_db_log_dir` |
| `set_log_level` | `String.t()` | `nil` | `Options::set_log_level` |
| `set_bytes_per_sync` | `non_neg_integer()` | `nil` | `Options::set_bytes_per_sync` |
| `set_wal_bytes_per_sync` | `non_neg_integer()` | `nil` | `Options::set_wal_bytes_per_sync` |
| `set_writable_file_max_buffer_size` | `non_neg_integer()` | `nil` | `Options::set_writable_file_max_buffer_size` |
| `set_allow_concurrent_memtable_write` | `boolean()` | `nil` | `Options::set_allow_concurrent_memtable_write` |
| `set_enable_write_thread_adaptive_yield` | `boolean()` | `nil` | `Options::set_enable_write_thread_adaptive_yield` |
| `set_max_sequential_skip_in_iterations` | `non_neg_integer()` | `nil` | `Options::set_max_sequential_skip_in_iterations` |
| `set_use_direct_reads` | `boolean()` | `nil` | `Options::set_use_direct_reads` |
| `set_use_direct_io_for_flush_and_compaction` | `boolean()` | `nil` | `Options::set_use_direct_io_for_flush_and_compaction` |
| `set_is_fd_close_on_exec` | `boolean()` | `nil` | `Options::set_is_fd_close_on_exec` |
| `set_table_cache_num_shard_bits` | `integer()` | `nil` | `Options::set_table_cache_num_shard_bits` |
| `set_target_file_size_multiplier` | `integer()` | `nil` | `Options::set_target_file_size_multiplier` |
| `set_min_write_buffer_number` | `integer()` | `nil` | `Options::set_min_write_buffer_number` |
| `set_max_write_buffer_number` | `integer()` | `nil` | `Options::set_max_write_buffer_number` |
| `set_write_buffer_size` | `non_neg_integer()` | `nil` | `Options::set_write_buffer_size` |
| `set_db_write_buffer_size` | `non_neg_integer()` | `nil` | `Options::set_db_write_buffer_size` |
| `set_max_bytes_for_level_base` | `non_neg_integer()` | `nil` | `Options::set_max_bytes_for_level_base` |
| `set_max_bytes_for_level_multiplier` | `float()` | `nil` | `Options::set_max_bytes_for_level_multiplier` |
| `set_max_manifest_file_size` | `non_neg_integer()` | `nil` | `Options::set_max_manifest_file_size` |
| `set_target_file_size_base` | `non_neg_integer()` | `nil` | `Options::set_target_file_size_base` |
| `set_min_write_buffer_number_to_merge` | `integer()` | `nil` | `Options::set_min_write_buffer_number_to_merge` |
| `set_level_zero_file_num_compaction_trigger` | `integer()` | `nil` | `Options::set_level_zero_file_num_compaction_trigger` |
| `set_level_zero_slowdown_writes_trigger` | `integer()` | `nil` | `Options::set_level_zero_slowdown_writes_trigger` |
| `set_level_zero_stop_writes_trigger` | `integer()` | `nil` | `Options::set_level_zero_stop_writes_trigger` |
| `set_compaction_style` | `String.t()` | `nil` | `Options::set_compaction_style` |
| `set_unordered_write` | `boolean()` | `nil` | `Options::set_unordered_write` |
| `set_max_subcompactions` | `non_neg_integer()` | `nil` | `Options::set_max_subcompactions` |
| `set_max_background_jobs` | `integer()` | `nil` | `Options::set_max_background_jobs` |
| `set_disable_auto_compactions` | `boolean()` | `nil` | `Options::set_disable_auto_compactions` |
| `set_memtable_huge_page_size` | `non_neg_integer()` | `nil` | `Options::set_memtable_huge_page_size` |
| `set_max_successive_merges` | `non_neg_integer()` | `nil` | `Options::set_max_successive_merges` |
| `set_bloom_locality` | `non_neg_integer()` | `nil` | `Options::set_bloom_locality` |
| `set_inplace_update_support` | `boolean()` | `nil` | `Options::set_inplace_update_support` |
| `set_inplace_update_locks` | `non_neg_integer()` | `nil` | `Options::set_inplace_update_locks` |
| `set_max_bytes_for_level_multiplier_additional` | `String.t()` | `nil` | `Options::set_max_bytes_for_level_multiplier_additional` |
| `set_max_write_buffer_size_to_maintain` | `integer()` | `nil` | `Options::set_max_write_buffer_size_to_maintain` |
| `set_enable_pipelined_write` | `boolean()` | `nil` | `Options::set_enable_pipelined_write` |
| `set_min_level_to_compress` | `integer()` | `nil` | `Options::set_min_level_to_compress` |
| `set_report_bg_io_stats` | `boolean()` | `nil` | `Options::set_report_bg_io_stats` |
| `set_max_total_wal_size` | `non_neg_integer()` | `nil` | `Options::set_max_total_wal_size` |
| `set_wal_recovery_mode` | `String.t()` | `nil` | `Options::set_wal_recovery_mode` |
| `enable_statistics` | `boolean()` | `nil` | `Options::enable_statistics` |
| `set_stats_dump_period_sec` | `non_neg_integer()` | `nil` | `Options::set_stats_dump_period_sec` |
| `set_stats_persist_period_sec` | `non_neg_integer()` | `nil` | `Options::set_stats_persist_period_sec` |
| `set_advise_random_on_open` | `boolean()` | `nil` | `Options::set_advise_random_on_open` |
| `set_use_adaptive_mutex` | `boolean()` | `nil` | `Options::set_use_adaptive_mutex` |
| `set_num_levels` | `integer()` | `nil` | `Options::set_num_levels` |
| `set_memtable_prefix_bloom_ratio` | `float()` | `nil` | `Options::set_memtable_prefix_bloom_ratio` |
| `set_max_compaction_bytes` | `non_neg_integer()` | `nil` | `Options::set_max_compaction_bytes` |
| `set_wal_dir` | `String.t()` | `nil` | `Options::set_wal_dir` |
| `set_wal_ttl_seconds` | `non_neg_integer()` | `nil` | `Options::set_wal_ttl_seconds` |
| `set_wal_size_limit_mb` | `non_neg_integer()` | `nil` | `Options::set_wal_size_limit_mb` |
| `set_manifest_preallocation_size` | `non_neg_integer()` | `nil` | `Options::set_manifest_preallocation_size` |
| `set_skip_stats_update_on_db_open` | `boolean()` | `nil` | `Options::set_skip_stats_update_on_db_open` |
| `set_keep_log_file_num` | `non_neg_integer()` | `nil` | `Options::set_keep_log_file_num` |
| `set_allow_mmap_writes` | `boolean()` | `nil` | `Options::set_allow_mmap_writes` |
| `set_allow_mmap_reads` | `boolean()` | `nil` | `Options::set_allow_mmap_reads` |
| `set_manual_wal_flush` | `boolean()` | `nil` | `Options::set_manual_wal_flush` |
| `set_atomic_flush` | `boolean()` | `nil` | `Options::set_atomic_flush` |
| `set_ratelimiter` | `String.t()` | `nil` | `Options::set_ratelimiter` |
| `set_max_log_file_size` | `non_neg_integer()` | `nil` | `Options::set_max_log_file_size` |
| `set_log_file_time_to_roll` | `non_neg_integer()` | `nil` | `Options::set_log_file_time_to_roll` |
| `set_recycle_log_file_num` | `non_neg_integer()` | `nil` | `Options::set_recycle_log_file_num` |
| `set_soft_pending_compaction_bytes_limit` | `non_neg_integer()` | `nil` | `Options::set_soft_pending_compaction_bytes_limit` |
| `set_hard_pending_compaction_bytes_limit` | `non_neg_integer()` | `nil` | `Options::set_hard_pending_compaction_bytes_limit` |
| `set_arena_block_size` | `non_neg_integer()` | `nil` | `Options::set_arena_block_size` |
| `set_dump_malloc_stats` | `boolean()` | `nil` | `Options::set_dump_malloc_stats` |
| `set_memtable_whole_key_filtering` | `boolean()` | `nil` | `Options::set_memtable_whole_key_filtering` |
| `set_enable_blob_files` | `boolean()` | `nil` | `Options::set_enable_blob_files` |
| `set_min_blob_size` | `non_neg_integer()` | `nil` | `Options::set_min_blob_size` |
| `set_blob_file_size` | `non_neg_integer()` | `nil` | `Options::set_blob_file_size` |
| `set_blob_compression_type` | `String.t()` | `nil` | `Options::set_blob_compression_type` |
| `set_enable_blob_gc` | `boolean()` | `nil` | `Options::set_enable_blob_gc` |
| `set_blob_gc_age_cutoff` | `float()` | `nil` | `Options::set_blob_gc_age_cutoff` |
| `set_blob_gc_force_threshold` | `float()` | `nil` | `Options::set_blob_gc_force_threshold` |
| `set_blob_compaction_readahead_size` | `non_neg_integer()` | `nil` | `Options::set_blob_compaction_readahead_size` |
| `set_prefix_extractor_prefix_length` | `non_neg_integer()` | `nil` | `Options::set_prefix_extractor_prefix_length` |
| `merge_operator` | `String.t()` | `nil` | merge callback registration |

## Range-Iterator Read Options

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `iterate_lower_bound` | `String.t()` | `nil` | RocksDB inclusive iterator lower bound. |
| `iterate_upper_bound` | `String.t()` | `nil` | RocksDB exclusive iterator upper bound. |

Binary range boundaries should normally be passed through the explicit `from`
and `to` arguments of `iterator_range/5`; these two compatibility options retain
their existing string contract.

## Batch Write Options

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `sync` | `boolean()` | `false` | Request a synchronous WAL flush before success. |
| `disable_wal` | `boolean()` | `false` | Disable WAL for rebuildable bulk-load data. |

`sync: true` with `disable_wal: true` is rejected as
`{:error, :invalid_write_options}`.

## Iterator-Take Options

| Key | Type | Default | Meaning |
| --- | --- | --- | --- |
| `max_entries` | `1..100_000` | required | Maximum rows copied in one call. |
| `max_bytes` | `1..67_108_864` | none | Maximum combined key/value payload, except one oversized first row. |

Malformed bounds return `{:error, :invalid_iterator_options}`. Byte limits
exclude normal Erlang term overhead.
