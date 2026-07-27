backend =
  case System.fetch_env!("EX_ROCKET_BACKEND") do
    "legacy" -> ExRocket
    "maintained" -> ExRocket.RustRocksDB
    other -> raise "unknown EX_ROCKET_BACKEND=#{inspect(other)}"
  end

path = System.fetch_env!("EX_ROCKET_COMPAT_PATH")

assert = fn
  expected, expected -> :ok
  expected, actual -> raise "expected #{inspect(expected)}, got #{inspect(actual)}"
end

assert.(:ok, backend.destroy(path))
{:ok, db} = backend.open(path)

assert.(:ok, backend.put(db, "plain", "plain-value"))
assert.(:ok, backend.put(db, "empty", <<>>))
assert.(:ok, backend.put(db, "unicode", "Grüße — Καλημέρα — こんにちは"))
assert.(:ok, backend.put(db, <<0, 1, 2, 255>>, <<255, 2, 1, 0>>))
assert.(:ok, backend.put(db, "large", :binary.copy(<<0, 1, 2, 3>>, 256)))

term = %{answer: 42, nested: [:a, {:tuple, true}], binary: <<0, 255>>}
assert.(:ok, backend.put(db, "erlang-term", :erlang.term_to_binary(term)))

assert.(
  {:ok, 4},
  backend.write_batch(db, [
    {:put, "batch-a", "A"},
    {:put, "batch-b", "B"},
    {:put, "deleted", "temporary"},
    {:delete, "deleted"}
  ])
)

assert.(:ok, backend.create_cf(db, "compat_cf"))
assert.(:ok, backend.put_cf(db, "compat_cf", "cf-plain", "cf-value"))
assert.(:ok, backend.put_cf(db, "compat_cf", "cf-term", :erlang.term_to_binary(term)))

assert.(
  {:ok, 2},
  backend.write_batch(db, [
    {:put_cf, "compat_cf", "cf-batch-a", "A"},
    {:put_cf, "compat_cf", "cf-batch-b", "B"}
  ])
)

IO.puts("wrote compatibility fixture with #{System.fetch_env!("EX_ROCKET_BACKEND")}")
