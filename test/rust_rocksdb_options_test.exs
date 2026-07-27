defmodule ExRocket.RustRocksDBOptionsTest do
  use ExUnit.Case, async: false

  alias ExRocket.RustRocksDB, as: DB

  setup do
    path =
      Path.join(System.tmp_dir!(), "rust_rocksdb_options_#{System.unique_integer([:positive])}")

    DB.destroy(path)
    on_exit(fn -> DB.destroy(path) end)
    %{path: path}
  end

  test "opens with the established practical option set", %{path: path} do
    assert {:ok, db} =
             DB.open(path, %{
               create_if_missing: true,
               set_max_open_files: 1000,
               set_use_fsync: false,
               set_bytes_per_sync: 8_388_608,
               set_table_cache_num_shard_bits: 6,
               set_max_write_buffer_number: 8,
               set_write_buffer_size: 8_388_608,
               set_target_file_size_base: 16_777_216,
               set_min_write_buffer_number_to_merge: 2,
               set_level_zero_stop_writes_trigger: 2000,
               set_level_zero_slowdown_writes_trigger: 0,
               set_disable_auto_compactions: true,
               set_compaction_style: "Universal",
               set_max_bytes_for_level_multiplier_additional: "1",
               set_ratelimiter: "1048576,100000,10"
             })

    assert is_reference(db)
  end

  test "uses prefix extractor and iterator read bounds", %{path: path} do
    assert {:ok, db} =
             DB.open(path, %{
               create_if_missing: true,
               set_prefix_extractor_prefix_length: 3
             })

    assert {:ok, 4} =
             DB.write_batch(db, [
               {:put, "aaa1", "1"},
               {:put, "aaa2", "2"},
               {:put, "bbb1", "3"},
               {:put, "ccc1", "4"}
             ])

    assert {:ok, prefix} = DB.prefix_iterator(db, "aaa")
    assert {:ok, "aaa1", "1"} = DB.next(prefix)
    assert {:ok, "aaa2", "2"} = DB.next(prefix)
    assert :end_of_iterator = DB.next(prefix)

    assert {:ok, bounded} =
             DB.iterator_range(db, {:start}, :undefined, :undefined, %{
               iterate_lower_bound: "bbb1",
               iterate_upper_bound: "ccc1"
             })

    assert {:ok, "bbb1", "3"} = DB.next(bounded)
    assert :end_of_iterator = DB.next(bounded)
  end

  test "RocksDB 11 accepts the removed SST-size option as a compatibility no-op", %{path: path} do
    assert {:ok, _db} =
             DB.open(path, %{
               create_if_missing: true,
               set_skip_checking_sst_file_sizes_on_db_open: true
             })
  end
end
