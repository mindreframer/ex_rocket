path =
  Path.join(
    System.tmp_dir!(),
    "ex_rocket_consumer_smoke_#{System.unique_integer([:positive, :monotonic])}"
  )

{:ok, db} = ExRocket.open(path)

{:ok, 2} =
  ExRocket.write_batch(db, [{:put, "key/1", "value/1"}, {:put, "key/2", "value/2"}], %{sync: true})

:ok = ExRocket.flush_wal(db, true)
{:ok, "value/1"} = ExRocket.get(db, "key/1")
:ok = ExRocket.close(db)
{:error, :closed} = ExRocket.get(db, "key/1")

{:ok, reopened} = ExRocket.open(path)
{:ok, "value/2"} = ExRocket.get(reopened, "key/2")
:ok = ExRocket.close(reopened)
:ok = ExRocket.destroy(path)

IO.puts("Precompiled public API smoke passed")
