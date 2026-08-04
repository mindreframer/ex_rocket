path = System.fetch_env!("EX_ROCKET_DURABILITY_PATH")
mode = System.get_env("EX_ROCKET_FAILURE_MODE", "complete")

{:ok, db} = ExRocket.open(path)

if mode == "before_dirty", do: System.halt(0)

{:ok, 1} =
  ExRocket.write_batch(db, [{:put, "materialization/state", "dirty:42"}], %{sync: true})

if mode == "after_dirty", do: System.halt(0)

{:ok, 1} = ExRocket.write_batch(db, [{:put, "projection/account/1", "alice"}])

if mode == "during_projection", do: System.halt(0)

{:ok, 1} = ExRocket.write_batch(db, [{:put, "projection/account/2", "bob"}])

if mode == "before_clean", do: System.halt(0)

{:ok, 1} =
  ExRocket.write_batch(db, [{:put, "materialization/state", "clean:42"}], %{sync: true})

# The source cursor advances only after the durable clean marker succeeds.
{:ok, 1} =
  ExRocket.write_batch(db, [{:put, "materialization/source_cursor", "42"}], %{sync: true})

if mode == "during_close" do
  :ok = ExRocket.close(db)
end

System.halt(0)
