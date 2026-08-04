path = System.fetch_env!("EX_ROCKET_DURABILITY_PATH")

{:ok, db} = ExRocket.open(path)

{:ok, 1} =
  ExRocket.write_batch(db, [{:put, "materialization/state", "dirty:42"}], %{sync: true})

{:ok, 2} =
  ExRocket.write_batch(db, [
    {:put, "projection/account/1", "alice"},
    {:put, "projection/account/2", "bob"}
  ])

{:ok, 1} =
  ExRocket.write_batch(db, [{:put, "materialization/state", "clean:42"}], %{sync: true})

# The source cursor advances only after the durable clean marker succeeds.
{:ok, 1} =
  ExRocket.write_batch(db, [{:put, "materialization/source_cursor", "42"}], %{sync: true})

System.halt(0)
