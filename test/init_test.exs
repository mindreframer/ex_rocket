defmodule ExRocket.Init.Test do
  use ExRocket.Case, async: true

  describe "create or open database" do
    test "open", context do
      {:ok, db} =
        ExRocket.open(context.db_path, %{
          create_if_missing: true,
          set_max_open_files: 1000,
          set_use_fsync: false,
          set_bytes_per_sync: 8_388_608,
          set_table_cache_num_shard_bits: 6,
          set_max_write_buffer_number: 32,
          set_write_buffer_size: 536_870_912,
          set_target_file_size_base: 1_073_741_824,
          set_min_write_buffer_number_to_merge: 4,
          set_level_zero_stop_writes_trigger: 2000,
          set_level_zero_slowdown_writes_trigger: 0,
          set_max_background_jobs: 4,
          set_disable_auto_compactions: true,
          set_compaction_style: "Universal",
          set_max_bytes_for_level_multiplier_additional: "1",
          set_ratelimiter: "1048576,100000,10"
        })

      assert is_reference(db)
    end

    test "open_default", context do
      {:ok, db} = ExRocket.open(context.db_path)
      assert is_reference(db)
    end

    test "open_multi_ptr", context do
      1..5
      |> Enum.each(fn idx ->
        {:ok, db1} = ExRocket.open("#{context.db_path}_#{idx}")
        assert is_reference(db1)
      end)
    end

    test "open_for_read_only", context do
      test = self()

      spawn(fn ->
        {:ok, db} = ExRocket.open(context.db_path)
        :ok = ExRocket.put(db, "k1", "v1")
        send(test, :ok)
      end)

      assert_receive(:ok, 1000)

      {:ok, db_read} = ExRocket.open_for_read_only(context.db_path)
      {:ok, "v1"} = ExRocket.get(db_read, "k1")

      {:error, "Not implemented: Not supported operation in read only mode."} =
        ExRocket.put(db_read, "k2", "v2")
    end
  end

  describe "destroy or repair database" do
    test "destroy", context do
      test = self()
      path = context.db_path <> "_for_destroy"

      spawn(fn ->
        {:ok, db} = ExRocket.open(path)
        true = is_reference(db)
        :ok = ExRocket.close(db)
        send(test, :ok)
      end)

      assert_receive(:ok, 1000)
      assert :ok == ExRocket.destroy(path)
    end

    test "repair", context do
      test = self()

      spawn(fn ->
        {:ok, db} = ExRocket.open(context.db_path)
        true = is_reference(db)
        :ok = ExRocket.close(db)
        send(test, :ok)
      end)

      assert_receive(:ok, 1000)
      assert :ok == ExRocket.repair(context.db_path)
    end
  end

  describe "db tools" do
    test "get_db_path", context do
      path = context.db_path
      {:ok, db} = ExRocket.open(path)
      {:ok, ^path} = ExRocket.get_db_path(db)
    end

    test "latest_sequence_number", context do
      {:ok, db} = ExRocket.open(context.db_path)
      {:ok, 0} = ExRocket.latest_sequence_number(db)
      :ok = ExRocket.put(db, "k1", "v1")
      {:ok, 1} = ExRocket.latest_sequence_number(db)
      :ok = ExRocket.put(db, "k2", "v2")
      {:ok, 2} = ExRocket.latest_sequence_number(db)
    end
  end
end
