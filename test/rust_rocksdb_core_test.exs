defmodule ExRocket.RustRocksDBCoreTest do
  use ExUnit.Case, async: false

  alias ExRocket.RustRocksDB, as: DB

  setup do
    path = Path.join(System.tmp_dir!(), "rust_rocksdb_core_#{System.unique_integer([:positive])}")
    DB.destroy(path)
    on_exit(fn -> DB.destroy(path) end)
    %{path: path}
  end

  test "opens, reports metadata, and performs core KV operations", %{path: path} do
    assert {:ok, db} = DB.open(path)
    assert {:ok, ^path} = DB.get_db_path(db)
    assert {:ok, sequence} = DB.latest_sequence_number(db)
    assert is_integer(sequence)

    assert :undefined = DB.get(db, "missing")
    assert {:ok, "fallback"} = DB.get(db, "missing", "fallback")
    assert :ok = DB.put(db, "key", "value")
    assert {:ok, "value"} = DB.get(db, "key")

    term = %{answer: 42}
    assert :ok = DB.put(db, "term", :erlang.term_to_binary(term))
    assert {:ok, ^term} = DB.getb(db, "term")

    assert :ok = DB.delete(db, "key")
    assert :undefined = DB.get(db, "key")
  end

  test "opens an existing database read-only", %{path: path} do
    assert {:ok, db} = DB.open(path)
    assert :ok = DB.put(db, "key", "value")
    db = nil
    :erlang.garbage_collect()
    assert nil == db

    assert {:ok, read_only} = DB.open_for_read_only(path)
    assert {:ok, "value"} = DB.get(read_only, "key")
    assert {:error, _reason} = DB.put(read_only, "key", "changed")
  end

  test "repairs and destroys a database", %{path: path} do
    assert {:ok, db} = DB.open(path)
    assert :ok = DB.put(db, "key", "value")
    db = nil
    :erlang.garbage_collect()
    assert nil == db
    assert :ok = DB.repair(path)
    assert :ok = DB.destroy(path)
    assert {:ok, _new_db} = DB.open(path)
  end
end
