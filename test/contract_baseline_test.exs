defmodule ExRocket.ContractBaselineTest do
  use ExUnit.Case, async: true

  @project_root Path.expand("..", __DIR__)

  @public_functions MapSet.new(
                      close: 1,
                      create_backup: 2,
                      create_cf: 2,
                      create_cf: 3,
                      create_checkpoint: 2,
                      delete: 2,
                      delete_cf: 3,
                      delete_range: 3,
                      delete_range_cf: 4,
                      destroy: 1,
                      destroy: 2,
                      drop_cf: 2,
                      flush_wal: 2,
                      get: 2,
                      get: 3,
                      get_backup_info: 1,
                      get_cf: 3,
                      get_cf: 4,
                      get_cfb: 3,
                      get_db_path: 1,
                      getb: 2,
                      iterator: 2,
                      iterator_cf: 3,
                      iterator_range: 4,
                      iterator_range: 5,
                      iterator_take: 2,
                      key_may_exist: 2,
                      key_may_exist_cf: 3,
                      latest_sequence_number: 1,
                      list_cf: 1,
                      list_cf: 2,
                      lxcode: 0,
                      merge: 3,
                      merge_cf: 4,
                      merge_cfb: 4,
                      mergeb: 3,
                      multi_get: 2,
                      multi_get_cf: 2,
                      next: 1,
                      open: 1,
                      open: 2,
                      open_cf: 2,
                      open_cf: 3,
                      open_cf_for_read_only: 2,
                      open_cf_for_read_only: 3,
                      open_for_read_only: 1,
                      open_for_read_only: 2,
                      prefix_iterator: 2,
                      prefix_iterator_cf: 3,
                      purge_old_backups: 2,
                      put: 3,
                      put_cf: 4,
                      repair: 1,
                      repair: 2,
                      restore_from_backup: 2,
                      restore_from_backup: 3,
                      snapshot: 1,
                      snapshot_get: 2,
                      snapshot_get: 3,
                      snapshot_get_cf: 3,
                      snapshot_get_cf: 4,
                      snapshot_iterator: 2,
                      snapshot_iterator_cf: 3,
                      snapshot_multi_get: 2,
                      snapshot_multi_get_cf: 2,
                      write_batch: 2,
                      write_batch: 3
                    )

  @nif_schedulers %{
    "close" => "DirtyIo",
    "create_backup" => "DirtyIo",
    "create_cf" => "DirtyIo",
    "create_checkpoint" => "DirtyIo",
    "delete" => "DirtyIo",
    "delete_cf" => "DirtyIo",
    "delete_range" => "DirtyIo",
    "delete_range_cf" => "DirtyIo",
    "destroy" => "DirtyIo",
    "drop_cf" => "DirtyIo",
    "flush_wal" => "DirtyIo",
    "get" => "DirtyIo",
    "get_backup_info" => "DirtyIo",
    "get_cf" => "DirtyIo",
    "get_db_path" => "DirtyIo",
    "iterator" => "DirtyIo",
    "iterator_cf" => "DirtyIo",
    "iterator_range" => "DirtyIo",
    "iterator_take" => "DirtyIo",
    "key_may_exist" => "DirtyIo",
    "key_may_exist_cf" => "DirtyIo",
    "latest_sequence_number" => "DirtyIo",
    "list_cf" => "DirtyIo",
    "lxcode" => "Normal",
    "merge" => "DirtyIo",
    "merge_cf" => "DirtyIo",
    "multi_get" => "DirtyIo",
    "multi_get_cf" => "DirtyIo",
    "next" => "DirtyIo",
    "open" => "DirtyIo",
    "open_cf" => "DirtyIo",
    "open_cf_for_read_only" => "DirtyIo",
    "open_for_read_only" => "DirtyIo",
    "prefix_iterator" => "DirtyIo",
    "prefix_iterator_cf" => "DirtyIo",
    "purge_old_backups" => "DirtyIo",
    "put" => "DirtyIo",
    "put_cf" => "DirtyIo",
    "repair" => "DirtyIo",
    "restore_from_backup" => "DirtyIo",
    "snapshot" => "DirtyIo",
    "snapshot_get" => "DirtyIo",
    "snapshot_get_cf" => "DirtyIo",
    "snapshot_iterator" => "DirtyIo",
    "snapshot_iterator_cf" => "DirtyIo",
    "snapshot_multi_get" => "DirtyIo",
    "snapshot_multi_get_cf" => "DirtyIo",
    "write_batch" => "DirtyIo"
  }

  test "public function inventory is explicit" do
    public_functions =
      ExRocket.__info__(:functions)
      |> MapSet.new()
      |> MapSet.delete({:rustler_init, 0})

    assert public_functions == @public_functions
  end

  test "native NIF and scheduler baseline is explicit" do
    source = File.read!(Path.join(@project_root, "native/rocker/src/nif.rs"))

    actual =
      ~r/#\[rustler::nif(?:\(schedule = "(DirtyIo)"\))?\]\s*pub fn ([a-z_]+)/
      |> Regex.scan(source)
      |> Map.new(fn [_, scheduler, name] -> {name, scheduler_or_normal(scheduler)} end)

    assert actual == @nif_schedulers

    inventory = File.read!(Path.join(@project_root, "@meta/@wiki/ROADMAP002-BASELINE.md"))
    audit = File.read!(Path.join(@project_root, "@meta/@wiki/ROADMAP002-SCHEDULER-AUDIT.md"))

    Enum.each(Map.keys(actual), fn name ->
      assert inventory =~ "`#{name}`"
      assert audit =~ "`#{name}`"
    end)

    assert for({name, "Normal"} <- actual, do: name) == ["lxcode"]
  end

  test "option decoders and their baseline behavior are inventoried" do
    options = File.read!(Path.join(@project_root, "native/rocker/src/options.rs"))
    read_options = File.read!(Path.join(@project_root, "native/rocker/src/read_options.rs"))
    inventory = File.read!(Path.join(@project_root, "@meta/@wiki/ROADMAP002-BASELINE.md"))

    assert options =~ "Decoder<'a> for RockerOptions"
    assert read_options =~ "Decoder<'a> for RockerReadOptions"
    assert inventory =~ "unknown keys are silently ignored"
  end

  test "public documentation uses canonical iterator and option names" do
    readme = File.read!(Path.join(@project_root, "README.md"))
    cheatsheet = File.read!(Path.join(@project_root, "CHEATSHEET.md"))

    refute readme =~ ":end_of_table"
    refute cheatsheet =~ ":end_of_table"
    assert cheatsheet =~ ":end_of_iterator"
    assert cheatsheet =~ "set_max_open_files:"
    assert cheatsheet =~ "set_write_buffer_size:"
    assert readme =~ "Atomic visibility is not the same as machine-crash durability"
  end

  defp scheduler_or_normal(""), do: "Normal"
  defp scheduler_or_normal(scheduler), do: scheduler
end
