defmodule ExRocket.IteratorBenchmark do
  def run do
    count = String.to_integer(System.get_env("ITERATOR_BENCH_COUNT", "50000"))
    page_size = String.to_integer(System.get_env("ITERATOR_BENCH_PAGE_SIZE", "1000"))

    path =
      Path.join(
        System.tmp_dir!(),
        "ex_rocket_iterator_bench_#{System.unique_integer([:positive])}"
      )

    parent = self()

    {pid, monitor} =
      spawn_monitor(fn ->
        {:ok, db} = ExRocket.open(path)

        1..count
        |> Enum.chunk_every(5_000)
        |> Enum.each(fn indexes ->
          operations =
            Enum.map(indexes, fn index ->
              key = :erlang.iolist_to_binary(:io_lib.format("~12..0B", [index]))
              {:put, key, :binary.copy(<<rem(index, 251)>>, 128)}
            end)

          {:ok, _} = ExRocket.write_batch(db, operations)
        end)

        {:ok, next_iterator} = ExRocket.iterator(db, {:start})
        {next_us, next_rows} = :timer.tc(fn -> count_next(next_iterator, 0) end)

        {:ok, take_iterator} = ExRocket.iterator(db, {:start})
        {take_us, take_rows} = :timer.tc(fn -> count_take(take_iterator, page_size, 0) end)

        send(parent, {:results, next_us, next_rows, take_us, take_rows})
      end)

    receive do
      {:results, next_us, next_rows, take_us, take_rows} ->
        IO.puts("rows=#{count} page_size=#{page_size}")
        IO.puts("next/1: #{next_rows} rows in #{next_us} us")
        IO.puts("iterator_take/2: #{take_rows} rows in #{take_us} us")
    end

    receive do
      {:DOWN, ^monitor, :process, ^pid, :normal} -> :ok
    end

    eventually_destroy(path)
  end

  defp count_next(iterator, count) do
    case ExRocket.next(iterator) do
      {:ok, _key, _value} -> count_next(iterator, count + 1)
      :end_of_iterator -> count
    end
  end

  defp count_take(iterator, page_size, count) do
    case ExRocket.iterator_take(iterator, %{max_entries: page_size}) do
      {:ok, rows, :more} -> count_take(iterator, page_size, count + length(rows))
      {:ok, rows, :end_of_iterator} -> count + length(rows)
    end
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

ExRocket.IteratorBenchmark.run()
