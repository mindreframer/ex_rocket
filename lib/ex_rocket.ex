defmodule ExRocket do
  @moduledoc """
  ExRocket — an Elixir NIF wrapper around RocksDB, powered by the maintained
  `rust-rocksdb` crate.
  """

  alias :erlang, as: Erlang

  @opaque db :: reference()
  @opaque iterator :: reference()
  @opaque snapshot :: reference() | {:snap, db(), reference()}

  @type batch_operation ::
          {:put, binary(), binary()}
          | {:delete, binary()}
          | {:merge, binary(), binary()}
          | {:put_cf, String.t(), binary(), binary()}
          | {:delete_cf, String.t(), binary()}
          | {:merge_cf, String.t(), binary(), binary()}

  @type write_options :: %{
          optional(:sync) => boolean(),
          optional(:disable_wal) => boolean()
        }

  @type iterator_take_options :: %{
          required(:max_entries) => pos_integer(),
          optional(:max_bytes) => pos_integer()
        }

  @type iterator_status :: :more | :end_of_iterator
  @type consistency_error ::
          :closed
          | :resource_busy
          | :invalid_write_options
          | :invalid_iterator_options
          | {:unknown_option, atom()}

  @version Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :ex_rocket,
    crate: "rocker",
    base_url: "https://github.com/mindreframer/ex_rocket/releases/download/v#{@version}",
    nif_versions: ["2.16"],
    targets: ~w(
      aarch64-apple-darwin
      x86_64-apple-darwin

      aarch64-unknown-linux-gnu
      aarch64-unknown-linux-musl
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl

      x86_64-pc-windows-msvc
    ),
    force_build: String.downcase(System.get_env("FORCE_BUILD", "nope")) in ["1", "true", "yes"],
    version: @version

  def lxcode, do: Erlang.nif_error(:nif_not_loaded)
  def latest_sequence_number(_db_ref), do: Erlang.nif_error(:nif_not_loaded)
  def open(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def open_for_read_only(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def destroy(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def repair(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def get_db_path(_db_ref), do: Erlang.nif_error(:nif_not_loaded)
  def put(_db_ref, _key, _value), do: Erlang.nif_error(:nif_not_loaded)
  def get(_db_ref, _key), do: Erlang.nif_error(:nif_not_loaded)

  def get(db_ref, key, default) do
    case get(db_ref, key) do
      :undefined -> {:ok, default}
      result -> result
    end
  end

  def getb(db_ref, key) do
    case get(db_ref, key) do
      :undefined -> :undefined
      {:ok, value} -> {:ok, :erlang.binary_to_term(value)}
    end
  end

  def delete(_db_ref, _key), do: Erlang.nif_error(:nif_not_loaded)
  def merge(_db_ref, _key, _operand), do: Erlang.nif_error(:nif_not_loaded)

  def mergeb(db_ref, key, operand),
    do: merge(db_ref, key, :erlang.term_to_binary(operand))

  def merge_cf(_db_ref, _cf_name, _key, _operand), do: Erlang.nif_error(:nif_not_loaded)

  def merge_cfb(db_ref, cf_name, key, operand),
    do: merge_cf(db_ref, cf_name, key, :erlang.term_to_binary(operand))

  @spec write_batch(db(), [batch_operation()]) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def write_batch(db_ref, operations), do: write_batch(db_ref, operations, %{})

  @spec write_batch(db(), [batch_operation()], write_options()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def write_batch(_db_ref, _operations, _write_options), do: Erlang.nif_error(:nif_not_loaded)

  @spec flush_wal(db(), boolean()) :: :ok | {:error, term()}
  def flush_wal(_db_ref, _sync), do: Erlang.nif_error(:nif_not_loaded)

  def delete_range(_db_ref, _from, _to), do: Erlang.nif_error(:nif_not_loaded)
  def multi_get(_db_ref, _keys), do: Erlang.nif_error(:nif_not_loaded)
  def key_may_exist(_db_ref, _key), do: Erlang.nif_error(:nif_not_loaded)
  def iterator(_db_ref, _mode), do: Erlang.nif_error(:nif_not_loaded)

  def iterator_range(_db_ref, _mode, _from, _to, _read_options \\ %{}),
    do: Erlang.nif_error(:nif_not_loaded)

  def prefix_iterator(_db_ref, _prefix), do: Erlang.nif_error(:nif_not_loaded)
  def next(_iterator_ref), do: Erlang.nif_error(:nif_not_loaded)

  @spec iterator_take(iterator(), iterator_take_options()) ::
          {:ok, [{binary(), binary()}], iterator_status()} | {:error, term()}
  def iterator_take(_iterator_ref, _options), do: Erlang.nif_error(:nif_not_loaded)

  @spec close(db()) :: :ok | {:error, :resource_busy | term()}
  def close(_db_ref), do: Erlang.nif_error(:nif_not_loaded)

  def create_cf(_db_ref, _cf_name, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def open_cf(_path, _cf_names, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)

  def open_cf_for_read_only(_path, _cf_names, _options \\ %{}),
    do: Erlang.nif_error(:nif_not_loaded)

  def list_cf(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def drop_cf(_db_ref, _cf_name), do: Erlang.nif_error(:nif_not_loaded)
  def put_cf(_db_ref, _cf_name, _key, _value), do: Erlang.nif_error(:nif_not_loaded)
  def get_cf(_db_ref, _cf_name, _key), do: Erlang.nif_error(:nif_not_loaded)

  def get_cf(db_ref, cf_name, key, default) do
    case get_cf(db_ref, cf_name, key) do
      :undefined -> {:ok, default}
      result -> result
    end
  end

  def get_cfb(db_ref, cf_name, key) do
    case get_cf(db_ref, cf_name, key) do
      :undefined -> :undefined
      {:ok, value} -> {:ok, :erlang.binary_to_term(value)}
    end
  end

  def delete_cf(_db_ref, _cf_name, _key), do: Erlang.nif_error(:nif_not_loaded)
  def delete_range_cf(_db_ref, _cf_name, _from, _to), do: Erlang.nif_error(:nif_not_loaded)
  def multi_get_cf(_db_ref, _keys), do: Erlang.nif_error(:nif_not_loaded)
  def key_may_exist_cf(_db_ref, _cf_name, _key), do: Erlang.nif_error(:nif_not_loaded)
  def iterator_cf(_db_ref, _cf_name, _mode), do: Erlang.nif_error(:nif_not_loaded)
  def prefix_iterator_cf(_db_ref, _cf_name, _prefix), do: Erlang.nif_error(:nif_not_loaded)
  def snapshot(_db_ref), do: Erlang.nif_error(:nif_not_loaded)
  def snapshot_get(_snapshot_ref, _key), do: Erlang.nif_error(:nif_not_loaded)

  def snapshot_get(snapshot_ref, key, default) do
    case snapshot_get(snapshot_ref, key) do
      :undefined -> {:ok, default}
      result -> result
    end
  end

  def snapshot_get_cf(_snapshot_ref, _cf_name, _key), do: Erlang.nif_error(:nif_not_loaded)

  def snapshot_get_cf(snapshot_ref, cf_name, key, default) do
    case snapshot_get_cf(snapshot_ref, cf_name, key) do
      :undefined -> {:ok, default}
      result -> result
    end
  end

  def snapshot_multi_get(_snapshot_ref, _keys), do: Erlang.nif_error(:nif_not_loaded)
  def snapshot_multi_get_cf(_snapshot_ref, _keys), do: Erlang.nif_error(:nif_not_loaded)
  def snapshot_iterator(_snapshot_ref, _mode), do: Erlang.nif_error(:nif_not_loaded)
  def snapshot_iterator_cf(_snapshot_ref, _cf_name, _mode), do: Erlang.nif_error(:nif_not_loaded)
  def create_checkpoint(_db_ref, _path), do: Erlang.nif_error(:nif_not_loaded)
  def create_backup(_db_ref, _path), do: Erlang.nif_error(:nif_not_loaded)
  def get_backup_info(_backup_path), do: Erlang.nif_error(:nif_not_loaded)
  def purge_old_backups(_backup_path, _keep), do: Erlang.nif_error(:nif_not_loaded)

  def restore_from_backup(_backup_path, _restore_path, _backup_id),
    do: Erlang.nif_error(:nif_not_loaded)

  def restore_from_backup(backup_path, restore_path),
    do: restore_from_backup(backup_path, restore_path, -1)
end
