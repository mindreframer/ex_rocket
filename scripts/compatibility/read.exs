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

{:ok, column_families} = backend.list_cf(path)
true = "default" in column_families
true = "compat_cf" in column_families
{:ok, db} = backend.open_cf(path, ["compat_cf"])

assert.({:ok, "plain-value"}, backend.get(db, "plain"))
assert.({:ok, <<>>}, backend.get(db, "empty"))
assert.({:ok, "Grüße — Καλημέρα — こんにちは"}, backend.get(db, "unicode"))
assert.({:ok, <<255, 2, 1, 0>>}, backend.get(db, <<0, 1, 2, 255>>))
assert.({:ok, :binary.copy(<<0, 1, 2, 3>>, 256)}, backend.get(db, "large"))

term = %{answer: 42, nested: [:a, {:tuple, true}], binary: <<0, 255>>}
assert.({:ok, term}, backend.getb(db, "erlang-term"))
assert.({:ok, "A"}, backend.get(db, "batch-a"))
assert.({:ok, "B"}, backend.get(db, "batch-b"))
assert.(:undefined, backend.get(db, "deleted"))

assert.({:ok, "cf-value"}, backend.get_cf(db, "compat_cf", "cf-plain"))
assert.({:ok, term}, backend.get_cfb(db, "compat_cf", "cf-term"))
assert.({:ok, "A"}, backend.get_cf(db, "compat_cf", "cf-batch-a"))
assert.({:ok, "B"}, backend.get_cf(db, "compat_cf", "cf-batch-b"))

{:ok, sequence} = backend.latest_sequence_number(db)
true = sequence > 0

IO.puts("read compatibility fixture with #{System.fetch_env!("EX_ROCKET_BACKEND")}")
