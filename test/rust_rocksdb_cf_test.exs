defmodule ExRocket.RustRocksDBColumnFamilyTest do
  use ExUnit.Case, async: false

  alias ExRocket.RustRocksDB, as: DB

  setup do
    path = Path.join(System.tmp_dir!(), "rust_rocksdb_cf_#{System.unique_integer([:positive])}")
    DB.destroy(path)
    on_exit(fn -> DB.destroy(path) end)
    {:ok, db} = DB.open(path)
    assert :ok = DB.create_cf(db, "secondary")
    %{db: db, path: path}
  end

  test "performs CF lifecycle and KV operations", %{db: db, path: path} do
    assert {:ok, names} = DB.list_cf(path)
    assert "default" in names
    assert "secondary" in names

    assert :ok = DB.put_cf(db, "secondary", "key", "value")
    assert {:ok, "value"} = DB.get_cf(db, "secondary", "key")
    assert {:ok, "fallback"} = DB.get_cf(db, "secondary", "missing", "fallback")

    term = %{backend: :maintained}
    assert :ok = DB.put_cf(db, "secondary", "term", :erlang.term_to_binary(term))
    assert {:ok, ^term} = DB.get_cfb(db, "secondary", "term")

    assert :ok = DB.delete_cf(db, "secondary", "key")
    assert :undefined = DB.get_cf(db, "secondary", "key")
    assert {:error, :unknown_cf} = DB.get_cf(db, "unknown", "key")
  end

  test "supports CF batches and bulk reads", %{db: db} do
    assert {:ok, 3} =
             DB.write_batch(db, [
               {:put_cf, "secondary", "k1", "v1"},
               {:put_cf, "secondary", "k2", "v2"},
               {:put_cf, "secondary", "k3", "v3"}
             ])

    assert {:ok, [{:ok, "v1"}, :undefined, {:ok, "v3"}]} =
             DB.multi_get_cf(db, [
               {"secondary", "k1"},
               {"secondary", "missing"},
               {"secondary", "k3"}
             ])

    assert {:ok, true} = DB.key_may_exist_cf(db, "secondary", "k2")
    assert :ok = DB.delete_range_cf(db, "secondary", "k1", "k3")
    assert :undefined = DB.get_cf(db, "secondary", "k1")
    assert {:ok, "v3"} = DB.get_cf(db, "secondary", "k3")
  end

  test "iterates a CF", %{db: db} do
    assert :ok = DB.put_cf(db, "secondary", "a", "1")
    assert :ok = DB.put_cf(db, "secondary", "b", "2")

    assert {:ok, iterator} = DB.iterator_cf(db, "secondary", {:start})
    assert {:ok, "a", "1"} = DB.next(iterator)
    assert {:ok, "b", "2"} = DB.next(iterator)
    assert :end_of_iterator = DB.next(iterator)

    assert {:ok, prefix} = DB.prefix_iterator_cf(db, "secondary", "a")
    assert {:ok, "a", "1"} = DB.next(prefix)
  end

  test "reopens all CFs read-write and read-only", %{db: db, path: path} do
    assert :ok = DB.put_cf(db, "secondary", "key", "value")
    db = nil
    :erlang.garbage_collect()
    assert nil == db

    assert {:ok, writable} = DB.open_cf(path, ["secondary"])
    assert {:ok, "value"} = DB.get_cf(writable, "secondary", "key")
    writable = nil
    :erlang.garbage_collect()
    assert nil == writable

    assert {:ok, read_only} = DB.open_cf_for_read_only(path, ["secondary"])
    assert {:ok, "value"} = DB.get_cf(read_only, "secondary", "key")
    assert {:error, _} = DB.put_cf(read_only, "secondary", "key", "changed")
  end
end
