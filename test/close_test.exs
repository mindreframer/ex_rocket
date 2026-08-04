defmodule ExRocket.CloseTest do
  use ExUnit.Case, async: false

  test "close is idempotent, releases the path, and every DB operation reports closed" do
    path = temp_path("contract")
    checkpoint_path = temp_path("checkpoint")
    backup_path = temp_path("backup")
    on_exit(fn -> cleanup_paths([path, checkpoint_path, backup_path]) end)

    assert {:ok, db} = ExRocket.open(path)
    assert :ok = ExRocket.create_cf(db, "rows")
    assert :ok = ExRocket.put(db, "key", "value")
    assert :ok = ExRocket.put_cf(db, "rows", "key", "value")

    assert :ok = ExRocket.close(db)
    assert :ok = ExRocket.close(db)

    operations = [
      {:latest_sequence_number, fn -> ExRocket.latest_sequence_number(db) end},
      {:get_db_path, fn -> ExRocket.get_db_path(db) end},
      {:put, fn -> ExRocket.put(db, "new", "value") end},
      {:get, fn -> ExRocket.get(db, "key") end},
      {:get_default, fn -> ExRocket.get(db, "key", "default") end},
      {:getb, fn -> ExRocket.getb(db, "key") end},
      {:delete, fn -> ExRocket.delete(db, "key") end},
      {:merge, fn -> ExRocket.merge(db, "key", "1") end},
      {:mergeb, fn -> ExRocket.mergeb(db, "key", {:int_add, 1}) end},
      {:merge_cf, fn -> ExRocket.merge_cf(db, "rows", "key", "1") end},
      {:merge_cfb, fn -> ExRocket.merge_cfb(db, "rows", "key", {:int_add, 1}) end},
      {:write_batch, fn -> ExRocket.write_batch(db, [{:put, "new", "value"}]) end},
      {:write_batch_options,
       fn -> ExRocket.write_batch(db, [{:put, "new", "value"}], %{sync: true}) end},
      {:flush_wal, fn -> ExRocket.flush_wal(db, true) end},
      {:delete_range, fn -> ExRocket.delete_range(db, "a", "z") end},
      {:multi_get, fn -> ExRocket.multi_get(db, ["key"]) end},
      {:key_may_exist, fn -> ExRocket.key_may_exist(db, "key") end},
      {:create_cf, fn -> ExRocket.create_cf(db, "later") end},
      {:drop_cf, fn -> ExRocket.drop_cf(db, "rows") end},
      {:put_cf, fn -> ExRocket.put_cf(db, "rows", "new", "value") end},
      {:get_cf, fn -> ExRocket.get_cf(db, "rows", "key") end},
      {:get_cf_default, fn -> ExRocket.get_cf(db, "rows", "key", "default") end},
      {:get_cfb, fn -> ExRocket.get_cfb(db, "rows", "key") end},
      {:delete_cf, fn -> ExRocket.delete_cf(db, "rows", "key") end},
      {:delete_range_cf, fn -> ExRocket.delete_range_cf(db, "rows", "a", "z") end},
      {:multi_get_cf, fn -> ExRocket.multi_get_cf(db, [{"rows", "key"}]) end},
      {:key_may_exist_cf, fn -> ExRocket.key_may_exist_cf(db, "rows", "key") end},
      {:iterator, fn -> ExRocket.iterator(db, {:start}) end},
      {:iterator_range, fn -> ExRocket.iterator_range(db, {:start}, :undefined, :undefined) end},
      {:prefix_iterator, fn -> ExRocket.prefix_iterator(db, "key") end},
      {:iterator_cf, fn -> ExRocket.iterator_cf(db, "rows", {:start}) end},
      {:prefix_iterator_cf, fn -> ExRocket.prefix_iterator_cf(db, "rows", "key") end},
      {:snapshot, fn -> ExRocket.snapshot(db) end},
      {:create_checkpoint, fn -> ExRocket.create_checkpoint(db, checkpoint_path) end},
      {:create_backup, fn -> ExRocket.create_backup(db, backup_path) end}
    ]

    Enum.each(operations, fn {name, operation} ->
      assert operation.() == {:error, :closed}, "#{name} did not return the closed contract"
    end)

    assert {:ok, reopened} = ExRocket.open_cf(path, ["rows"])
    assert {:ok, "value"} = ExRocket.get(reopened, "key")
    assert :ok = ExRocket.close(reopened)
    assert :ok = ExRocket.destroy(path)
  end

  test "regular iterators, snapshots, and snapshot iterators hold one close lease" do
    Enum.each([:iterator, :snapshot, :snapshot_iterator], fn kind ->
      path = temp_path(Atom.to_string(kind))
      assert {:ok, db} = ExRocket.open(path)
      assert :ok = ExRocket.put(db, "key", "value")

      parent = self()
      {pid, monitor} = spawn_monitor(fn -> hold_child_resource(parent, db, kind) end)

      assert_receive {:child_ready, ^pid}, 5_000
      assert {:error, :resource_busy} = ExRocket.close(db)

      send(pid, :release)
      assert_receive {:DOWN, ^monitor, :process, ^pid, :normal}, 5_000
      assert :ok = eventually_close(db)
      assert :ok = ExRocket.destroy(path)
    end)
  end

  test "failed child construction does not leak a database lease" do
    path = temp_path("failed-child")
    on_exit(fn -> cleanup_paths([path]) end)

    assert {:ok, db} = ExRocket.open(path)
    assert {:error, :unknown_cf} = ExRocket.iterator_cf(db, "missing", {:start})
    assert {:error, :unknown_cf} = ExRocket.prefix_iterator_cf(db, "missing", "prefix")
    assert :ok = ExRocket.close(db)
    assert :ok = ExRocket.destroy(path)
  end

  test "read-only and multi-CF resources share deterministic close semantics" do
    path = temp_path("open-modes")
    on_exit(fn -> cleanup_paths([path]) end)

    assert {:ok, db} = ExRocket.open(path)
    assert :ok = ExRocket.create_cf(db, "rows")
    assert :ok = ExRocket.close(db)

    assert {:ok, multi_cf} = ExRocket.open_cf(path, ["rows"])
    assert :ok = ExRocket.close(multi_cf)

    assert {:ok, read_only} = ExRocket.open_cf_for_read_only(path, ["rows"])
    assert :ok = ExRocket.close(read_only)
    assert {:error, :closed} = ExRocket.get(read_only, "key")

    assert :ok = ExRocket.destroy(path)
  end

  test "close racing child creation is linearized without deadlock or unsafe success" do
    Enum.each(1..50, fn iteration ->
      path = temp_path("race-#{iteration}")
      assert {:ok, db} = ExRocket.open(path)
      parent = self()

      {child, child_monitor} =
        spawn_monitor(fn ->
          receive do
            :go ->
              result = ExRocket.iterator(db, {:start})
              send(parent, {:child_result, self(), result_tag(result)})

              receive do
                :release -> :ok
              end
          end
        end)

      closer =
        Task.async(fn ->
          receive do
            :go -> ExRocket.close(db)
          end
        end)

      send(child, :go)
      send(closer.pid, :go)

      assert_receive {:child_result, ^child, child_result}, 5_000
      close_result = Task.await(closer, 5_000)

      assert {child_result, close_result} in [
               {:created, {:error, :resource_busy}},
               {:closed, :ok}
             ]

      send(child, :release)
      assert_receive {:DOWN, ^child_monitor, :process, ^child, :normal}, 5_000
      assert :ok = eventually_close(db)
      assert :ok = ExRocket.destroy(path)
    end)
  end

  defp hold_child_resource(parent, db, kind) do
    resource =
      case kind do
        :iterator ->
          {:ok, iterator} = ExRocket.iterator(db, {:start})
          iterator

        :snapshot ->
          {:ok, snapshot} = ExRocket.snapshot(db)
          snapshot

        :snapshot_iterator ->
          {:ok, snapshot} = ExRocket.snapshot(db)
          {:ok, iterator} = ExRocket.snapshot_iterator(snapshot, {:start})
          iterator
      end

    send(parent, {:child_ready, self()})

    receive do
      :release -> resource
    end
  end

  defp result_tag({:ok, iterator}) when is_reference(iterator), do: :created
  defp result_tag({:error, :closed}), do: :closed

  defp eventually_close(db, attempts \\ 100)
  defp eventually_close(_db, 0), do: {:error, :close_timeout}

  defp eventually_close(db, attempts) do
    :erlang.garbage_collect()

    case ExRocket.close(db) do
      :ok ->
        :ok

      {:error, :resource_busy} ->
        Process.sleep(10)
        eventually_close(db, attempts - 1)
    end
  end

  defp cleanup_paths(paths) do
    :erlang.garbage_collect()

    Enum.each(paths, fn path ->
      ExRocket.destroy(path)
      File.rm_rf(path)
    end)
  end

  defp temp_path(label) do
    Path.join(System.tmp_dir!(), "ex_rocket_close_#{label}_#{UUID.uuid4()}")
  end
end
