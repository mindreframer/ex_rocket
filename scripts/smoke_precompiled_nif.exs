source_path = Path.expand("../lib/ex_rocket.ex", __DIR__)
source_ast = source_path |> File.read!() |> Code.string_to_quoted!()

{_ast, functions} =
  Macro.prewalk(source_ast, MapSet.new(), fn
    {:def, _meta, [{name, _call_meta, args}, _body]} = node, functions
    when is_atom(name) ->
      args = args || []
      default_count = Enum.count(args, &match?({:\\, _, _}, &1))
      arities = (length(args) - default_count)..length(args)
      functions = Enum.reduce(arities, functions, &MapSet.put(&2, {name, &1}))
      {node, functions}

    node, functions ->
      {node, functions}
  end)

stubs =
  Enum.map(functions, fn {name, arity} ->
    args = for index <- 1..arity//1, do: Macro.var(String.to_atom("_arg#{index}"), nil)

    quote do
      def unquote(name)(unquote_splicing(args)), do: :erlang.nif_error(:nif_not_loaded)
    end
  end)

nif_path = System.fetch_env!("NIF_PATH") |> Path.rootname()

{:module, ExRocket, _binary, _term} =
  Module.create(
    ExRocket,
    quote do
      @on_load :__load_nif__
      def __load_nif__, do: :erlang.load_nif(unquote(String.to_charlist(nif_path)), 0)
      unquote_splicing(stubs)
    end,
    Macro.Env.location(__ENV__)
  )

unless ExRocket.lxcode() == {:ok, :vsn1}, do: raise("unexpected NIF response")

path =
  Path.join(
    System.tmp_dir!(),
    "ex_rocket_precompiled_smoke_#{System.unique_integer([:positive, :monotonic])}"
  )

{:error, {:unknown_option, :misspelled_option}} =
  ExRocket.open(path, %{misspelled_option: true})

{:ok, db} = ExRocket.open(path, %{})

{:ok, 2} =
  ExRocket.write_batch(
    db,
    [{:put, "key/1", "value/1"}, {:put, "key/2", "value/2"}],
    %{sync: true}
  )

:ok = ExRocket.flush_wal(db, true)
{:ok, "value/1"} = ExRocket.get(db, "key/1")
:ok = ExRocket.close(db)
:ok = ExRocket.close(db)
{:error, :closed} = ExRocket.get(db, "key/1")

{:ok, scan_db} = ExRocket.open(path, %{})
parent = self()

spawn(fn ->
  {:ok, iterator} = ExRocket.iterator(scan_db, {:start})
  {:ok, rows, :end_of_iterator} = ExRocket.iterator_take(iterator, %{max_entries: 10})
  send(parent, {:rows, rows})
end)

receive do
  {:rows, [{"key/1", "value/1"}, {"key/2", "value/2"}]} -> :ok
end

eventually_close = fn
  _close_attempt, 0 ->
    raise "iterator lease was not released"

  close_attempt, attempts ->
    case ExRocket.close(scan_db) do
      :ok ->
        :ok

      {:error, :resource_busy} ->
        :erlang.garbage_collect()
        Process.sleep(10)
        close_attempt.(close_attempt, attempts - 1)
    end
end

:ok = eventually_close.(eventually_close, 100)
:ok = ExRocket.destroy(path, %{})

IO.puts("NIF functional smoke test passed: #{nif_path}")
