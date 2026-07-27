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

nif_path = System.fetch_env!("NIF_PATH") |> String.trim_trailing(".so")

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
IO.puts("NIF smoke test passed: #{nif_path}")
