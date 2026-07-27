alias ExRocket.RustRocksDB, as: Maintained

seconds = String.to_integer(System.get_env("BENCH_TIME", "10"))
warmup = String.to_integer(System.get_env("BENCH_WARMUP", "3"))
root = Path.join(System.tmp_dir!(), "ex_rocket_compare_#{System.unique_integer([:positive])}")

backends = [legacy: ExRocket, maintained: Maintained]

contexts =
  Map.new(backends, fn {name, backend} ->
    path = "#{root}_#{name}"
    backend.destroy(path)
    {:ok, db} = backend.open(path)
    :ok = backend.put(db, "hot-key", "hot-value")
    {name, %{backend: backend, db: db, path: path}}
  end)

Benchee.run(
  %{
    "read" => fn %{backend: backend, db: db} ->
      {:ok, "hot-value"} = backend.get(db, "hot-key")
    end,
    "write" => fn %{backend: backend, db: db} ->
      value = System.unique_integer([:positive]) |> Integer.to_string()
      :ok = backend.put(db, value, value)
    end
  },
  inputs: contexts,
  warmup: warmup,
  time: seconds,
  memory_time: 0,
  parallel: 1
)

Enum.each(contexts, fn {_name, %{backend: backend, path: path}} -> backend.destroy(path) end)
