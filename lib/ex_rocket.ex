defmodule ExRocket do
  @moduledoc """
  ExRocket's primary public API.

  The API is backed by the maintained `rust-rocksdb` implementation in
  `ExRocket.RustRocksDB`. Keeping this facade preserves the established module
  name while both modules exercise the same native backend.
  """

  alias ExRocket.RustRocksDB, as: Backend

  @doc "Returns the ExRocket NIF API version."
  def lxcode do
    case Backend.lxcode() do
      {:ok, :maintained, version} -> {:ok, version}
      result -> result
    end
  end

  # Injected by RustlerPrecompiled on NIF-backed modules; retained for exact
  # function inventory compatibility while this facade delegates the backend.
  defdelegate rustler_init(), to: Backend

  defdelegate latest_sequence_number(db_ref), to: Backend
  defdelegate open(path, options \\ %{}), to: Backend
  defdelegate open_for_read_only(path, options \\ %{}), to: Backend
  defdelegate destroy(path, options \\ %{}), to: Backend
  defdelegate repair(path, options \\ %{}), to: Backend
  defdelegate get_db_path(db_ref), to: Backend
  defdelegate put(db_ref, key, value), to: Backend
  defdelegate get(db_ref, key), to: Backend
  defdelegate get(db_ref, key, default), to: Backend
  defdelegate getb(db_ref, key), to: Backend
  defdelegate delete(db_ref, key), to: Backend
  defdelegate merge(db_ref, key, operand), to: Backend
  defdelegate mergeb(db_ref, key, operand), to: Backend
  defdelegate merge_cf(db_ref, cf_name, key, operand), to: Backend
  defdelegate merge_cfb(db_ref, cf_name, key, operand), to: Backend
  defdelegate write_batch(db_ref, operations), to: Backend
  defdelegate iterator(db_ref, mode), to: Backend
  defdelegate iterator_range(db_ref, mode, from, to, read_options \\ %{}), to: Backend
  defdelegate next(iterator_ref), to: Backend
  defdelegate prefix_iterator(db_ref, prefix), to: Backend
  defdelegate create_cf(db_ref, cf_name, options \\ %{}), to: Backend
  defdelegate open_cf(path, cf_names, options \\ %{}), to: Backend
  defdelegate open_cf_for_read_only(path, cf_names, options \\ %{}), to: Backend
  defdelegate list_cf(path, options \\ %{}), to: Backend
  defdelegate drop_cf(db_ref, cf_name), to: Backend
  defdelegate put_cf(db_ref, cf_name, key, value), to: Backend
  defdelegate get_cf(db_ref, cf_name, key), to: Backend
  defdelegate get_cf(db_ref, cf_name, key, default), to: Backend
  defdelegate get_cfb(db_ref, cf_name, key), to: Backend
  defdelegate delete_cf(db_ref, cf_name, key), to: Backend
  defdelegate iterator_cf(db_ref, cf_name, mode), to: Backend
  defdelegate prefix_iterator_cf(db_ref, cf_name, prefix), to: Backend
  defdelegate delete_range(db_ref, from, to), to: Backend
  defdelegate delete_range_cf(db_ref, cf_name, from, to), to: Backend
  defdelegate multi_get(db_ref, keys), to: Backend
  defdelegate multi_get_cf(db_ref, keys), to: Backend
  defdelegate key_may_exist(db_ref, key), to: Backend
  defdelegate key_may_exist_cf(db_ref, cf_name, key), to: Backend
  defdelegate snapshot(db_ref), to: Backend
  defdelegate snapshot_get(snapshot_ref, key), to: Backend
  defdelegate snapshot_get(snapshot_ref, key, default), to: Backend
  defdelegate snapshot_get_cf(snapshot_ref, cf_name, key), to: Backend
  defdelegate snapshot_get_cf(snapshot_ref, cf_name, key, default), to: Backend
  defdelegate snapshot_multi_get(snapshot_ref, keys), to: Backend
  defdelegate snapshot_multi_get_cf(snapshot_ref, keys), to: Backend
  defdelegate snapshot_iterator(snapshot_ref, mode), to: Backend
  defdelegate snapshot_iterator_cf(snapshot_ref, cf_name, mode), to: Backend
  defdelegate create_checkpoint(db_ref, path), to: Backend
  defdelegate create_backup(db_ref, path), to: Backend
  defdelegate get_backup_info(backup_path), to: Backend
  defdelegate purge_old_backups(backup_path, keep), to: Backend
  defdelegate restore_from_backup(backup_path, restore_path, backup_id), to: Backend
  defdelegate restore_from_backup(backup_path, restore_path), to: Backend
end
