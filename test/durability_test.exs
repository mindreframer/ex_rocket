defmodule ExRocket.DurabilityTest do
  use ExUnit.Case, async: false

  @writer Path.expand("support/durability_writer.exs", __DIR__)

  test "synchronous checkpoint boundaries survive an independent BEAM halt and reopen" do
    path = Path.join(System.tmp_dir!(), "ex_rocket_durability_#{UUID.uuid4()}")

    on_exit(fn -> eventually_destroy(path) end)

    {output, status} =
      System.cmd("mix", ["run", "--no-compile", @writer],
        cd: File.cwd!(),
        env: [
          {"MIX_ENV", "test"},
          {"EX_ROCKET_DURABILITY_PATH", path}
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output

    assert {:ok, db} = ExRocket.open(path)
    assert {:ok, "clean:42"} = ExRocket.get(db, "materialization/state")
    assert {:ok, "alice"} = ExRocket.get(db, "projection/account/1")
    assert {:ok, "bob"} = ExRocket.get(db, "projection/account/2")
    assert {:ok, "42"} = ExRocket.get(db, "materialization/source_cursor")
  end

  defp eventually_destroy(path, attempts \\ 50)
  defp eventually_destroy(_path, 0), do: :ok

  defp eventually_destroy(path, attempts) do
    :erlang.garbage_collect()

    case ExRocket.destroy(path) do
      :ok ->
        :ok

      {:error, _reason} ->
        Process.sleep(10)
        eventually_destroy(path, attempts - 1)
    end
  end
end
