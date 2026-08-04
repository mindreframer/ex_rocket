defmodule ExRocket.ReleaseBenchmark do
  def run do
    batch_count = env_integer("RELEASE_BENCH_BATCHES", 200)
    batch_size = env_integer("RELEASE_BENCH_BATCH_SIZE", 100)
    sync_count = env_integer("RELEASE_BENCH_SYNCS", 100)
    close_count = env_integer("RELEASE_BENCH_CLOSES", 50)

    path =
      Path.join(
        System.tmp_dir!(),
        "ex_rocket_release_bench_#{System.unique_integer([:positive])}"
      )

    {:ok, db} = ExRocket.open(path)

    {batch_us, :ok} =
      :timer.tc(fn ->
        Enum.each(1..batch_count, fn batch ->
          operations =
            Enum.map(1..batch_size, fn index ->
              {:put, "batch/#{batch}/#{index}", :binary.copy(<<rem(index, 251)>>, 128)}
            end)

          {:ok, ^batch_size} = ExRocket.write_batch(db, operations)
        end)
      end)

    {sync_us, :ok} =
      :timer.tc(fn ->
        Enum.each(1..sync_count, fn index ->
          {:ok, 1} =
            ExRocket.write_batch(db, [{:put, "sync/marker", Integer.to_string(index)}], %{
              sync: true
            })
        end)
      end)

    {:ok, iterator} = ExRocket.iterator(db, {:start})
    memory_before = process_memory()
    {:ok, page, _status} = ExRocket.iterator_take(iterator, %{max_entries: 1_000})
    memory_after = process_memory()
    payload_bytes = Enum.sum(for {key, value} <- page, do: byte_size(key) + byte_size(value))

    :erlang.garbage_collect()
    assert_close_after_iterator(db)
    :ok = ExRocket.destroy(path)

    close_latencies =
      Enum.map(1..close_count, fn index ->
        close_path = "#{path}_close_#{index}"
        {:ok, close_db} = ExRocket.open(close_path)
        {close_us, :ok} = :timer.tc(fn -> ExRocket.close(close_db) end)
        :ok = ExRocket.destroy(close_path)
        close_us
      end)
      |> Enum.sort()

    batch_operations = batch_count * batch_size

    IO.puts("batch_operations=#{batch_operations}")
    IO.puts("nonsync_batch_ops_per_second=#{rate(batch_operations, batch_us)}")
    IO.puts("sync_boundaries_per_second=#{rate(sync_count, sync_us)}")
    IO.puts("page_rows=#{length(page)} page_payload_bytes=#{payload_bytes}")
    IO.puts("page_process_memory_delta_bytes=#{max(memory_after - memory_before, 0)}")
    IO.puts("close_p50_us=#{percentile(close_latencies, 0.50)}")
    IO.puts("close_p95_us=#{percentile(close_latencies, 0.95)}")
    IO.puts("close_max_us=#{List.last(close_latencies)}")
  end

  defp assert_close_after_iterator(db, attempts \\ 100)
  defp assert_close_after_iterator(_db, 0), do: raise("iterator lease did not release")

  defp assert_close_after_iterator(db, attempts) do
    case ExRocket.close(db) do
      :ok ->
        :ok

      {:error, :resource_busy} ->
        :erlang.garbage_collect()
        Process.sleep(10)
        assert_close_after_iterator(db, attempts - 1)
    end
  end

  defp process_memory do
    {:memory, bytes} = Process.info(self(), :memory)
    bytes
  end

  defp percentile(values, percentile) do
    Enum.at(values, max(ceil(length(values) * percentile) - 1, 0))
  end

  defp rate(count, microseconds) do
    Float.round(count * 1_000_000 / max(microseconds, 1), 1)
  end

  defp env_integer(name, default) do
    name |> System.get_env(Integer.to_string(default)) |> String.to_integer()
  end
end

ExRocket.ReleaseBenchmark.run()
