defmodule ExRocket.RustRocksDBPrimitivesTest do
  use ExUnit.Case, async: false

  alias ExRocket.RustRocksDB, as: DB

  setup do
    path =
      Path.join(
        System.tmp_dir!(),
        "rust_rocksdb_primitives_#{System.unique_integer([:positive])}"
      )

    DB.destroy(path)
    on_exit(fn -> DB.destroy(path) end)
    {:ok, db} = DB.open(path)
    %{db: db}
  end

  test "batch, multi-get, existence, and range deletion", %{db: db} do
    assert {:ok, 4} =
             DB.write_batch(db, [
               {:put, "k1", "v1"},
               {:put, "k2", "v2"},
               {:put, "k3", "v3"},
               {:delete, "missing"}
             ])

    assert {:ok, [{:ok, "v1"}, :undefined, {:ok, "v3"}]} =
             DB.multi_get(db, ["k1", "missing", "k3"])

    assert {:ok, true} = DB.key_may_exist(db, "k2")
    assert :ok = DB.delete_range(db, "k1", "k3")
    assert :undefined = DB.get(db, "k1")
    assert :undefined = DB.get(db, "k2")
    assert {:ok, "v3"} = DB.get(db, "k3")
  end

  test "iterates forward, reverse, and over ranges", %{db: db} do
    assert {:ok, 4} =
             DB.write_batch(db, Enum.map(1..4, &{:put, "k#{&1}", "v#{&1}"}))

    assert {:ok, iterator} = DB.iterator(db, {:start})
    assert {:ok, "k1", "v1"} = DB.next(iterator)
    assert {:ok, "k2", "v2"} = DB.next(iterator)

    assert {:ok, reverse} = DB.iterator(db, {:from, "k3", :reverse})
    assert {:ok, "k3", "v3"} = DB.next(reverse)
    assert {:ok, "k2", "v2"} = DB.next(reverse)

    assert {:ok, range} = DB.iterator_range(db, {:start}, "k2", "k4")
    assert {:ok, "k2", "v2"} = DB.next(range)
    assert {:ok, "k3", "v3"} = DB.next(range)
    assert :end_of_iterator = DB.next(range)
  end

  test "iterator resource retains its database", %{db: db} do
    assert :ok = DB.put(db, "key", "value")
    assert {:ok, iterator} = DB.prefix_iterator(db, "key")
    db = nil
    :erlang.garbage_collect()
    assert nil == db
    assert {:ok, "key", "value"} = DB.next(iterator)
  end
end
