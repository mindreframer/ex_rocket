defmodule ExRocket.RustRocksDBParityTest do
  use ExUnit.Case, async: false

  @backends [ExRocket, ExRocket.RustRocksDB]

  test "direct module exposes exactly the primary public API" do
    primary = MapSet.new(ExRocket.__info__(:functions))
    direct = MapSet.new(ExRocket.RustRocksDB.__info__(:functions))
    assert direct == primary
  end

  for backend <- @backends do
    @backend backend

    test "#{inspect(backend)} satisfies shared lifecycle and KV behavior" do
      backend = @backend

      path =
        Path.join(System.tmp_dir!(), "parity_#{backend}_#{System.unique_integer([:positive])}")

      backend.destroy(path)

      try do
        assert {:ok, db} = backend.open(path)
        assert :undefined = backend.get(db, "missing")
        assert :ok = backend.put(db, "key", "value")
        assert {:ok, "value"} = backend.get(db, "key")
        assert {:ok, 2} = backend.write_batch(db, [{:put, "a", "1"}, {:put, "b", "2"}])
        assert {:ok, [{:ok, "1"}, {:ok, "2"}]} = backend.multi_get(db, ["a", "b"])
        assert {:ok, iterator} = backend.iterator(db, {:start})
        assert {:ok, "a", "1"} = backend.next(iterator)
      after
        backend.destroy(path)
      end
    end
  end

  test "maintained backend handles concurrent reads and writes" do
    backend = ExRocket.RustRocksDB

    path =
      Path.join(System.tmp_dir!(), "maintained_concurrency_#{System.unique_integer([:positive])}")

    backend.destroy(path)
    {:ok, db} = backend.open(path)

    try do
      1..100
      |> Task.async_stream(
        fn number ->
          key = Integer.to_string(number)
          :ok = backend.put(db, key, key)
          {:ok, ^key} = backend.get(db, key)
        end,
        max_concurrency: 16,
        timeout: 10_000
      )
      |> Enum.each(fn result -> assert {:ok, {:ok, _}} = result end)
    after
      backend.destroy(path)
    end
  end

  test "maintained backend returns controlled errors for unknown CFs and read-only writes" do
    backend = ExRocket.RustRocksDB
    path = Path.join(System.tmp_dir!(), "maintained_errors_#{System.unique_integer([:positive])}")
    backend.destroy(path)

    try do
      {:ok, db} = backend.open(path)
      assert {:error, :unknown_cf} = backend.get_cf(db, "missing", "key")
      db = nil
      :erlang.garbage_collect()
      assert nil == db
      {:ok, read_only} = backend.open_for_read_only(path)
      assert {:error, _} = backend.put(read_only, "key", "value")
    after
      backend.destroy(path)
    end
  end
end
