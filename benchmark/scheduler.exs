defmodule ExRocket.SchedulerBenchmark do
  def run do
    rows = env_integer("SCHEDULER_BENCH_ROWS", 50_000)
    value_bytes = env_integer("SCHEDULER_BENCH_VALUE_BYTES", 2_048)
    workers = env_integer("SCHEDULER_BENCH_WORKERS", max(System.schedulers_online(), 2))
    heartbeat_ms = env_integer("SCHEDULER_BENCH_HEARTBEAT_MS", 5)

    path =
      Path.join(
        System.tmp_dir!(),
        "ex_rocket_scheduler_bench_#{System.unique_integer([:positive])}"
      )

    parent = self()

    {owner, monitor} =
      spawn_monitor(fn ->
        {:ok, db} = ExRocket.open(path)
        keys = populate(db, rows, value_bytes)

        {first_pass_us, ^rows} = :timer.tc(fn -> read_all(db, keys) end)
        {hot_pass_us, ^rows} = :timer.tc(fn -> read_all(db, keys) end)

        heartbeat = start_heartbeat(self(), heartbeat_ms)
        started_at = System.monotonic_time(:microsecond)

        worker_refs =
          for _ <- 1..workers do
            {_pid, ref} = spawn_monitor(fn -> read_all(db, keys) end)
            ref
          end

        heartbeats = wait_for_workers(MapSet.new(worker_refs), [])
        elapsed_us = System.monotonic_time(:microsecond) - started_at
        send(heartbeat, :stop)

        send(parent, {
          :results,
          rows,
          value_bytes,
          workers,
          first_pass_us,
          hot_pass_us,
          elapsed_us,
          heartbeat_stats(heartbeats)
        })
      end)

    receive do
      {:results, rows, value_bytes, workers, first_us, hot_us, elapsed_us, heartbeat} ->
        operations = rows * workers
        throughput = operations * 1_000_000 / max(elapsed_us, 1)

        IO.puts("rows=#{rows} value_bytes=#{value_bytes} workers=#{workers}")
        IO.puts("first_pass_us=#{first_us} hot_pass_us=#{hot_us}")
        IO.puts("concurrent_read_ops_per_second=#{Float.round(throughput, 1)}")
        IO.puts("heartbeat_samples=#{heartbeat.samples}")
        IO.puts("heartbeat_p95_us=#{heartbeat.p95_us} heartbeat_max_us=#{heartbeat.max_us}")
    end

    receive do
      {:DOWN, ^monitor, :process, ^owner, :normal} -> :ok
    end

    eventually_destroy(path)
  end

  defp populate(db, rows, value_bytes) do
    keys = Enum.map(1..rows, &:erlang.integer_to_binary/1)
    value = :binary.copy(<<42>>, value_bytes)

    keys
    |> Enum.chunk_every(5_000)
    |> Enum.each(fn chunk ->
      {:ok, _} = ExRocket.write_batch(db, Enum.map(chunk, &{:put, &1, value}))
    end)

    keys
  end

  defp read_all(db, keys) do
    Enum.each(keys, fn key -> {:ok, _value} = ExRocket.get(db, key) end)
    length(keys)
  end

  defp start_heartbeat(owner, interval_ms) do
    spawn(fn -> heartbeat_loop(owner, interval_ms) end)
  end

  defp heartbeat_loop(owner, interval_ms) do
    receive do
      :stop -> :ok
    after
      interval_ms ->
        send(owner, {:heartbeat, System.monotonic_time(:microsecond)})
        heartbeat_loop(owner, interval_ms)
    end
  end

  defp wait_for_workers(refs, heartbeats) do
    if MapSet.size(refs) == 0 do
      Enum.reverse(heartbeats)
    else
      receive do
        {:heartbeat, timestamp} ->
          wait_for_workers(refs, [timestamp | heartbeats])

        {:DOWN, ref, :process, _pid, :normal} ->
          wait_for_workers(MapSet.delete(refs, ref), heartbeats)

        {:DOWN, ref, :process, _pid, reason} ->
          raise "storage worker failed: #{inspect(ref)}: #{inspect(reason)}"
      end
    end
  end

  defp heartbeat_stats([_single]), do: %{samples: 1, p95_us: 0, max_us: 0}
  defp heartbeat_stats([]), do: %{samples: 0, p95_us: 0, max_us: 0}

  defp heartbeat_stats(timestamps) do
    intervals =
      timestamps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [left, right] -> right - left end)
      |> Enum.sort()

    p95_index = max(ceil(length(intervals) * 0.95) - 1, 0)

    %{
      samples: length(timestamps),
      p95_us: Enum.at(intervals, p95_index),
      max_us: List.last(intervals)
    }
  end

  defp env_integer(name, default) do
    name |> System.get_env(Integer.to_string(default)) |> String.to_integer()
  end

  defp eventually_destroy(path, attempts \\ 50)
  defp eventually_destroy(_path, 0), do: :ok

  defp eventually_destroy(path, attempts) do
    case ExRocket.destroy(path) do
      :ok ->
        :ok

      {:error, _} ->
        :erlang.garbage_collect()
        Process.sleep(10)
        eventually_destroy(path, attempts - 1)
    end
  end
end

ExRocket.SchedulerBenchmark.run()
