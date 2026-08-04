defmodule ExRocket.ConsistencyStressTest do
  use ExUnit.Case, async: false

  @rounds 10
  @rows 100

  test "mixed readers, writers, snapshots, bulk iterators, close, CFs, and reopen remain safe" do
    Enum.each(1..@rounds, fn round ->
      path = Path.join(System.tmp_dir!(), "ex_rocket_stress_#{round}_#{UUID.uuid4()}")
      assert {:ok, db} = ExRocket.open(path)
      assert :ok = ExRocket.create_cf(db, "rows")
      seed(db)

      parent = self()

      {snapshot_owner, snapshot_monitor} =
        spawn_monitor(fn ->
          {:ok, snapshot} = ExRocket.snapshot(db)
          {:ok, iterator} = ExRocket.snapshot_iterator(snapshot, {:start})
          send(parent, {:snapshot_ready, self()})
          send(parent, {:snapshot_rows, self(), drain(iterator, 0)})

          receive do
            :release -> :ok
          end
        end)

      assert_receive {:snapshot_ready, ^snapshot_owner}, 5_000

      writer =
        Task.async(fn ->
          Enum.each(1..@rows, fn index ->
            key = "live/#{index}"

            assert {:ok, 2} =
                     ExRocket.write_batch(db, [
                       {:put, key, "value/#{index}"},
                       {:put_cf, "rows", key, "cf-value/#{index}"}
                     ])
          end)
        end)

      readers =
        for offset <- 1..4 do
          Task.async(fn ->
            Enum.each(1..@rows, fn index ->
              key = "seed/#{rem(index + offset, @rows) + 1}"
              assert {:ok, _value} = ExRocket.get(db, key)
              assert {:ok, _value} = ExRocket.get_cf(db, "rows", key)
            end)
          end)
        end

      scanner =
        Task.async(fn ->
          {:ok, iterator} = ExRocket.iterator(db, {:start})
          drain(iterator, 0)
        end)

      assert {:error, :resource_busy} = ExRocket.close(db)

      Task.await(writer, 15_000)
      Enum.each(readers, &Task.await(&1, 15_000))
      assert Task.await(scanner, 15_000) >= @rows
      assert_receive {:snapshot_rows, ^snapshot_owner, @rows}, 5_000

      send(snapshot_owner, :release)
      assert_receive {:DOWN, ^snapshot_monitor, :process, ^snapshot_owner, :normal}, 5_000

      assert :ok = eventually_close(db)
      assert {:ok, reopened} = ExRocket.open_cf(path, ["rows"])
      assert {:ok, "value/100"} = ExRocket.get(reopened, "live/100")
      assert {:ok, "cf-value/100"} = ExRocket.get_cf(reopened, "rows", "live/100")
      assert :ok = ExRocket.close(reopened)
      assert :ok = ExRocket.destroy(path)
    end)
  end

  defp seed(db) do
    operations =
      Enum.flat_map(1..@rows, fn index ->
        key = "seed/#{index}"
        [{:put, key, "value/#{index}"}, {:put_cf, "rows", key, "cf-value/#{index}"}]
      end)

    assert {:ok, count} = ExRocket.write_batch(db, operations)
    assert count == @rows * 2
  end

  defp drain(iterator, count) do
    case ExRocket.iterator_take(iterator, %{max_entries: 25, max_bytes: 64 * 1024}) do
      {:ok, rows, :more} -> drain(iterator, count + length(rows))
      {:ok, rows, :end_of_iterator} -> count + length(rows)
    end
  end

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
end
