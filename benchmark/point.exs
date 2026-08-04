defmodule ExRocket.PointBenchmark do
  def run do
    operations = env_integer("POINT_BENCH_OPERATIONS", 100_000)

    path =
      Path.join(System.tmp_dir!(), "ex_rocket_point_bench_#{System.unique_integer([:positive])}")

    parent = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        {:ok, db} = ExRocket.open(path)
        :ok = ExRocket.put(db, "hot", "value")

        {read_us, :ok} =
          :timer.tc(fn ->
            Enum.each(1..operations, fn _ -> {:ok, "value"} = ExRocket.get(db, "hot") end)
          end)

        {write_us, :ok} =
          :timer.tc(fn ->
            Enum.each(1..operations, fn index ->
              :ok = ExRocket.put(db, :erlang.integer_to_binary(index), "value")
            end)
          end)

        send(parent, {:results, read_us, write_us})
      end)

    receive do
      {:results, read_us, write_us} ->
        read_rate = operations * 1_000_000 / max(read_us, 1)
        write_rate = operations * 1_000_000 / max(write_us, 1)
        IO.puts("operations=#{operations}")
        IO.puts("point_reads_per_second=#{Float.round(read_rate, 1)}")
        IO.puts("point_writes_per_second=#{Float.round(write_rate, 1)}")
    end

    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
    end

    eventually_destroy(path)
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

ExRocket.PointBenchmark.run()
