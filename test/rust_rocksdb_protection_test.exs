defmodule ExRocket.RustRocksDBProtectionTest do
  use ExUnit.Case, async: false

  alias ExRocket.RustRocksDB, as: DB

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "rust_rocksdb_protection_#{System.unique_integer([:positive])}"
      )

    paths = %{
      db: root,
      checkpoint: root <> "_checkpoint",
      backup: root <> "_backup",
      restore: root <> "_restore"
    }

    Enum.each(paths, fn {_name, path} -> DB.destroy(path) end)
    on_exit(fn -> Enum.each(paths, fn {_name, path} -> DB.destroy(path) end) end)
    {:ok, db} = DB.open(paths.db)
    %{handle: db, paths: paths}
  end

  test "snapshot preserves default and CF values and supports iteration", %{handle: db} do
    assert :ok = DB.create_cf(db, "secondary")
    assert :ok = DB.put(db, "key", "before")
    assert :ok = DB.put_cf(db, "secondary", "cf-key", "cf-before")
    assert {:ok, snapshot} = DB.snapshot(db)

    assert :ok = DB.put(db, "key", "after")
    assert :ok = DB.put_cf(db, "secondary", "cf-key", "cf-after")
    assert :ok = DB.put(db, "new", "new")

    assert {:ok, "before"} = DB.snapshot_get(snapshot, "key")
    assert {:ok, "fallback"} = DB.snapshot_get(snapshot, "missing", "fallback")
    assert {:ok, "cf-before"} = DB.snapshot_get_cf(snapshot, "secondary", "cf-key")
    assert {:ok, [{:ok, "before"}, :undefined]} = DB.snapshot_multi_get(snapshot, ["key", "new"])

    assert {:ok, [{:ok, "cf-before"}, :undefined]} =
             DB.snapshot_multi_get_cf(snapshot, [
               {"secondary", "cf-key"},
               {"secondary", "missing"}
             ])

    assert {:ok, iterator} = DB.snapshot_iterator(snapshot, {:start})
    assert {:ok, "key", "before"} = DB.next(iterator)
    assert :end_of_iterator = DB.next(iterator)

    assert {:ok, cf_iterator} = DB.snapshot_iterator_cf(snapshot, "secondary", {:start})
    assert {:ok, "cf-key", "cf-before"} = DB.next(cf_iterator)
  end

  test "creates a readable checkpoint", %{handle: db, paths: paths} do
    assert :ok = DB.put(db, "key", "checkpoint-value")
    assert :ok = DB.create_checkpoint(db, paths.checkpoint)
    assert {:ok, checkpoint} = DB.open(paths.checkpoint)
    assert {:ok, "checkpoint-value"} = DB.get(checkpoint, "key")
  end

  test "creates, reports, purges, and restores backups", %{handle: db, paths: paths} do
    assert :ok = DB.put(db, "key", "v1")
    assert {:ok, [{:backup, 1, _, _, _}]} = DB.create_backup(db, paths.backup)
    assert :ok = DB.put(db, "key", "v2")

    assert {:ok, [{:backup, 1, _, _, _}, {:backup, 2, _, _, _}]} =
             DB.create_backup(db, paths.backup)

    assert {:ok, [_, _]} = DB.get_backup_info(paths.backup)
    assert {:ok, [{:backup, 2, _, _, _}]} = DB.purge_old_backups(paths.backup, 1)

    assert :ok = DB.restore_from_backup(paths.backup, paths.restore)
    assert {:ok, restored} = DB.open(paths.restore)
    assert {:ok, "v2"} = DB.get(restored, "key")
  end
end
