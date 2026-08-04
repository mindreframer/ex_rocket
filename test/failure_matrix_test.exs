defmodule ExRocket.FailureMatrixTest do
  use ExUnit.Case, async: false

  @writer Path.expand("support/durability_writer.exs", __DIR__)

  @incomplete_modes [:after_dirty, :during_projection, :before_clean]
  @complete_modes [:after_clean, :during_close]

  test "checkpoint failure matrix has deterministic recovery actions" do
    Enum.each([:before_dirty | @incomplete_modes ++ @complete_modes], fn mode ->
      path = Path.join(System.tmp_dir!(), "ex_rocket_failure_#{mode}_#{UUID.uuid4()}")

      seed_previous_checkpoint(path)
      run_writer(path, mode)

      assert {:ok, db} = ExRocket.open(path)

      cond do
        mode == :before_dirty ->
          assert {:ok, "clean:41"} = ExRocket.get(db, "materialization/state")
          assert {:ok, "41"} = ExRocket.get(db, "materialization/source_cursor")
          assert :undefined = ExRocket.get(db, "projection/account/1")

        mode in @incomplete_modes ->
          assert {:ok, "dirty:42"} = ExRocket.get(db, "materialization/state")
          assert {:ok, "41"} = ExRocket.get(db, "materialization/source_cursor")

        mode in @complete_modes ->
          assert {:ok, "clean:42"} = ExRocket.get(db, "materialization/state")
          assert {:ok, "42"} = ExRocket.get(db, "materialization/source_cursor")
          assert {:ok, "alice"} = ExRocket.get(db, "projection/account/1")
          assert {:ok, "bob"} = ExRocket.get(db, "projection/account/2")
      end

      assert :ok = ExRocket.close(db)
      assert :ok = ExRocket.destroy(path)
    end)
  end

  defp seed_previous_checkpoint(path) do
    assert {:ok, db} = ExRocket.open(path)

    assert {:ok, 2} =
             ExRocket.write_batch(
               db,
               [
                 {:put, "materialization/state", "clean:41"},
                 {:put, "materialization/source_cursor", "41"}
               ],
               %{sync: true}
             )

    assert :ok = ExRocket.close(db)
  end

  defp run_writer(path, mode) do
    {output, status} =
      System.cmd("mix", ["run", "--no-compile", @writer],
        cd: File.cwd!(),
        env: [
          {"MIX_ENV", "test"},
          {"EX_ROCKET_DURABILITY_PATH", path},
          {"EX_ROCKET_FAILURE_MODE", Atom.to_string(mode)}
        ],
        stderr_to_stdout: true
      )

    assert status == 0, output
  end
end
